import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';

import type { JwtPayload } from '../auth/types/jwt-payload';
import { PrismaService } from '../prisma/prisma.service';

interface SocketData {
  userId: string;
  role: string;
  storeId?: string | null;
  kitchenId?: string | null;
}

/**
 * Banan realtime entrypoint. Each client opens one connection; on connect we
 * verify the JWT (passed via handshake auth or `?token=`) and auto-join the
 * rooms relevant to the user's role:
 *   - every user → `user:{id}`
 *   - merchant   → `store:{storeId}`
 *   - kitchen    → `kitchen:{kitchenId}`
 *
 * Customers additionally `order:subscribe` to a specific order to receive
 * fine-grained kitchen status updates while watching the tracking screen.
 */
// Same allowlist the HTTP server uses (CORS_ORIGINS). Read at module load
// because the gateway decorator runs before DI is available.
const WS_ALLOWED_ORIGINS = (process.env.CORS_ORIGINS ?? '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);
// Allow-all only as a LOCAL-DEV convenience when no allowlist is set. In
// production an empty/unset CORS_ORIGINS fails CLOSED for browser origins —
// matching the HTTP layer (main.ts), which treats an empty allowlist as
// "deny all cross-origin". This keeps the WS boundary consistent with HTTP.
const WS_ALLOW_ALL = WS_ALLOWED_ORIGINS.length === 0 && process.env.NODE_ENV !== 'production';

@WebSocketGateway({
  cors: {
    // Non-browser clients (no Origin header) are always allowed; otherwise the
    // origin must be on the allowlist. Reflecting any origin is never done.
    // Dropped `credentials` — auth is a Bearer token in the handshake.
    origin: (origin, cb) => {
      if (!origin || WS_ALLOW_ALL || WS_ALLOWED_ORIGINS.includes(origin)) {
        cb(null, true);
      } else {
        cb(null, false);
      }
    },
  },
})
export class RealtimeGateway implements OnGatewayConnection {
  private readonly logger = new Logger(RealtimeGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async handleConnection(client: Socket): Promise<void> {
    // Every client — guest or authed — joins the `public` room so it receives
    // catalog/config broadcasts (realtime menu sync). This lets a browsing
    // guest see a merchant's product / price / popup change without refresh.
    await client.join('public');

    const raw =
      (client.handshake.auth as { token?: string } | undefined)?.token ??
      (client.handshake.query?.token as string | undefined);
    // Anonymous (guest) connection — public room only, no user/role rooms.
    if (!raw) {
      this.logger.debug(`socket ${client.id} connected anonymously (public)`);
      return;
    }

    let payload: JwtPayload;
    try {
      payload = await this.jwt.verifyAsync<JwtPayload>(raw, {
        secret: this.config.get<string>('JWT_ACCESS_SECRET'),
      });
    } catch {
      // A *bad* token is suspicious — drop it (a genuine guest sends none).
      client.disconnect();
      return;
    }

    const data: SocketData = {
      userId: payload.sub,
      role: payload.role,
      storeId: payload.storeId,
      kitchenId: payload.kitchenId,
    };
    client.data = data;

    await client.join(`user:${data.userId}`);
    if ((data.role === 'MERCHANT_OWNER' || data.role === 'MERCHANT_STAFF') && data.storeId) {
      await client.join(`store:${data.storeId}`);
    }
    if ((data.role === 'KITCHEN_MANAGER' || data.role === 'KITCHEN_STAFF') && data.kitchenId) {
      await client.join(`kitchen:${data.kitchenId}`);
    }

    this.logger.debug(`socket ${client.id} connected as ${data.role} ${data.userId}`);
  }

  @SubscribeMessage('order:subscribe')
  async onOrderSubscribe(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { orderId?: string } | undefined,
  ) {
    const orderId = body?.orderId;
    if (!orderId) return;
    // Authorise BEFORE joining: a socket may only watch an order it owns or
    // serves. (An anonymous socket has no identity, so it can't subscribe to
    // any order room.) Without this, any client could join `order:<uuid>` and
    // receive that order's status events — mitigated only by UUID guessing.
    const data = client.data as SocketData | undefined;
    if (!data?.userId) return;
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: { customerId: true, storeId: true, kitchenId: true },
    });
    if (!order) return;
    const role = data.role;
    const allowed =
      role === 'ADMIN' ||
      order.customerId === data.userId ||
      ((role === 'MERCHANT_OWNER' || role === 'MERCHANT_STAFF') &&
        !!data.storeId &&
        data.storeId === order.storeId) ||
      ((role === 'KITCHEN_MANAGER' || role === 'KITCHEN_STAFF') &&
        !!order.kitchenId &&
        data.kitchenId === order.kitchenId);
    if (!allowed) {
      this.logger.warn(`socket ${client.id} (${data.userId}) denied order:subscribe ${orderId}`);
      return;
    }
    await client.join(`order:${orderId}`);
  }

  /** Helper called by services to emit to one or more rooms. */
  emit(rooms: string[], event: string, payload: unknown): void {
    if (!this.server) return;
    for (const r of rooms) this.server.to(r).emit(event, payload);
  }

  /**
   * Re-authorise an order room after the order changed kitchens. A kitchen
   * staff socket joins `order:{id}` while the order is at THEIR kitchen
   * (onOrderSubscribe authorises on the current kitchenId). That check is
   * point-in-time: when a merchant later transfers the order to another
   * kitchen, the old kitchen's socket stays in the room and would keep
   * receiving the new kitchen's `kitchen_status_changed` events. Socket.IO has
   * no automatic revocation, so we evict any kitchen-staff socket whose kitchen
   * no longer matches. Best-effort and idempotent — works across nodes via the
   * adapter. Customer/merchant subscribers are untouched (a transfer doesn't
   * change the order's customer or store).
   */
  async evictStaleKitchenSubscribers(
    orderId: string,
    currentKitchenId: string | null,
  ): Promise<void> {
    if (!this.server) return;
    const room = `order:${orderId}`;
    let sockets;
    try {
      sockets = await this.server.in(room).fetchSockets();
    } catch (err) {
      // Adapter failure — eviction is BEST-EFFORT and never the only defence:
      // sensitive kitchen-status events are no longer routed to order:{id}
      // (see transitionKitchen), so a stale socket can still be in this room
      // but won't receive the new kitchen's workflow. Log loudly.
      this.logger.error(
        `evictStaleKitchenSubscribers(${orderId}) fetchSockets failed: ${String(err)}`,
      );
      return;
    }
    for (const socket of sockets) {
      const data = socket.data as SocketData | undefined;
      if (
        data &&
        (data.role === 'KITCHEN_MANAGER' || data.role === 'KITCHEN_STAFF') &&
        data.kitchenId !== currentKitchenId
      ) {
        // Isolate per-socket: one failed leave must not skip the rest.
        try {
          socket.leave(room);
        } catch (err) {
          this.logger.error(`evict leave failed for ${socket.id} on ${room}: ${String(err)}`);
        }
      }
    }
  }
}

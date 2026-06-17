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

@WebSocketGateway({
  cors: {
    // Allow non-browser clients (no Origin header) and configured origins
    // only; reject everything else instead of reflecting any origin. When the
    // allowlist is empty (local dev) we permit all for convenience. Dropped
    // `credentials` — auth is a Bearer token in the handshake, not a cookie.
    origin: (origin, cb) => {
      if (
        !origin ||
        WS_ALLOWED_ORIGINS.length === 0 ||
        WS_ALLOWED_ORIGINS.includes(origin)
      ) {
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
    if (
      (data.role === 'MERCHANT_OWNER' || data.role === 'MERCHANT_STAFF') &&
      data.storeId
    ) {
      await client.join(`store:${data.storeId}`);
    }
    if (
      (data.role === 'KITCHEN_MANAGER' || data.role === 'KITCHEN_STAFF') &&
      data.kitchenId
    ) {
      await client.join(`kitchen:${data.kitchenId}`);
    }

    this.logger.debug(
      `socket ${client.id} connected as ${data.role} ${data.userId}`,
    );
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
      this.logger.warn(
        `socket ${client.id} (${data.userId}) denied order:subscribe ${orderId}`,
      );
      return;
    }
    await client.join(`order:${orderId}`);
  }

  /** Helper called by services to emit to one or more rooms. */
  emit(rooms: string[], event: string, payload: unknown): void {
    if (!this.server) return;
    for (const r of rooms) this.server.to(r).emit(event, payload);
  }
}

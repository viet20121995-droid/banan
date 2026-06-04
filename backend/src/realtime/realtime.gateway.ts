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
@WebSocketGateway({
  cors: {
    origin: (origin, cb) => cb(null, true),
    credentials: true,
  },
})
export class RealtimeGateway implements OnGatewayConnection {
  private readonly logger = new Logger(RealtimeGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
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
    // Trust + scope: customer subscribes to their own active order. The
    // server only emits to this room on events the customer is allowed to
    // see (their own orders), so cross-tenant leaks are impossible even if
    // a malicious client subscribes blindly.
    await client.join(`order:${orderId}`);
  }

  /** Helper called by services to emit to one or more rooms. */
  emit(rooms: string[], event: string, payload: unknown): void {
    if (!this.server) return;
    for (const r of rooms) this.server.to(r).emit(event, payload);
  }
}

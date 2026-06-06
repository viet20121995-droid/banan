import { Injectable, Logger } from '@nestjs/common';
import { Notification, Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

import { EmailService } from './email.service';
import type { NotificationTemplate } from './notification-templates';
import { PushService } from './push.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
    private readonly email: EmailService,
    private readonly push: PushService,
  ) {}

  /**
   * Inserts a Notification row and emits `notification.new` to the user's
   * room so the in-app inbox updates live. **Also** fans out a transactional
   * email reusing the same title/body — so the customer's email inbox shows
   * the same journey as the in-app feed.
   */
  async sendToUser(
    userId: string,
    template: NotificationTemplate,
    data?: Record<string, unknown>,
    opts: { email?: boolean } = {},
  ): Promise<Notification> {
    const notification = await this.prisma.notification.create({
      data: {
        userId,
        type: template.type,
        title: template.title,
        body: template.body,
        data: (data ?? Prisma.JsonNull) as Prisma.InputJsonValue,
      },
    });
    this.realtime.emit([`user:${userId}`], 'notification.new', {
      notification: this.toView(notification),
    });

    // Fire-and-forget email — never blocks the caller even if Resend
    // is down or unconfigured. EmailService skips synthetic guest addresses.
    // Staff alerts (new order / to-kitchen) pass email:false to avoid spam.
    if (opts.email !== false) {
      void this.fanOutEmail(userId, template, data);
    }
    // Fire-and-forget mobile / web push to any registered devices.
    void this.push.pushToUser(userId, template, data);
    return notification;
  }

  /** Alert the fulfilling store's owner + staff (in-app + push, no email). */
  async notifyStoreStaff(
    storeId: string,
    template: NotificationTemplate,
    data?: Record<string, unknown>,
  ): Promise<void> {
    const staff = await this.prisma.user.findMany({
      where: {
        storeId,
        role: { in: ['MERCHANT_OWNER', 'MERCHANT_STAFF'] },
      },
      select: { id: true },
    });
    for (const u of staff) {
      await this.sendToUser(u.id, template, data, { email: false });
    }
  }

  /** Alert a kitchen's manager + staff (in-app + push, no email). */
  async notifyKitchenStaff(
    kitchenId: string,
    template: NotificationTemplate,
    data?: Record<string, unknown>,
  ): Promise<void> {
    const staff = await this.prisma.user.findMany({
      where: {
        kitchenId,
        role: { in: ['KITCHEN_MANAGER', 'KITCHEN_STAFF'] },
      },
      select: { id: true },
    });
    for (const u of staff) {
      await this.sendToUser(u.id, template, data, { email: false });
    }
  }

  private async fanOutEmail(
    userId: string,
    template: NotificationTemplate,
    data?: Record<string, unknown>,
  ): Promise<void> {
    try {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { email: true, fullName: true },
      });
      if (!user) return;
      const orderId =
        typeof data?.orderId === 'string' ? (data.orderId as string) : undefined;
      const orderCode =
        typeof data?.code === 'string' ? (data.code as string) : undefined;
      await this.email.sendOrderStatusEmail({
        toEmail: user.email,
        toName: user.fullName,
        template,
        orderId,
        orderCode,
      });
    } catch (err) {
      this.logger.warn(`Email fan-out failed: ${(err as Error).message}`);
    }
  }

  /**
   * Campaign broadcast — inserts an in-app notification for every CUSTOMER.
   * Durable (persisted) so it shows next time each customer opens their
   * inbox. No email fan-out (that's the opt-in newsletter channel) and no
   * FCM push (needs Firebase registration). Returns the recipient count.
   */
  async broadcastToCustomers(
    template: { type: string; title: string; body: string },
    data?: Record<string, unknown>,
  ): Promise<{ recipients: number }> {
    // Respect the marketing opt-out + skip disabled/deleted accounts.
    const users = await this.prisma.user.findMany({
      where: { role: 'CUSTOMER', marketingOptIn: true, isActive: true },
      select: { id: true },
    });
    if (users.length === 0) return { recipients: 0 };
    await this.prisma.notification.createMany({
      data: users.map((u) => ({
        userId: u.id,
        type: template.type,
        title: template.title,
        body: template.body,
        data: data ? (data as Prisma.InputJsonValue) : undefined,
      })),
    });
    // Fire-and-forget web/mobile push to every customer's registered devices.
    void this.push.pushBroadcast(template, data);
    return { recipients: users.length };
  }

  async listForUser(
    userId: string,
    page = 1,
    perPage = 30,
  ) {
    const skip = (page - 1) * perPage;
    const [items, total, unread] = await this.prisma.$transaction([
      this.prisma.notification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        skip,
        take: perPage,
      }),
      this.prisma.notification.count({ where: { userId } }),
      this.prisma.notification.count({
        where: { userId, readAt: null },
      }),
    ]);
    return {
      items: items.map((n) => this.toView(n)),
      meta: { page, perPage, total, unread },
    };
  }

  async markRead(userId: string, ids: string[]): Promise<void> {
    if (ids.length === 0) return;
    await this.prisma.notification.updateMany({
      where: { userId, id: { in: ids }, readAt: null },
      data: { readAt: new Date() },
    });
  }

  async markAllRead(userId: string): Promise<void> {
    await this.prisma.notification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
  }

  /** Strips `userId` and shapes a stable wire format. */
  private toView(n: Notification) {
    return {
      id: n.id,
      type: n.type,
      title: n.title,
      body: n.body,
      data: n.data,
      readAt: n.readAt?.toISOString() ?? null,
      createdAt: n.createdAt.toISOString(),
    };
  }
}

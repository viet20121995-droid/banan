import { Injectable, Logger } from '@nestjs/common';
import { Notification, Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

import type { NotificationTemplate } from './notification-templates';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
  ) {}

  /**
   * Inserts a Notification row and emits `notification.new` to the user's
   * room so the in-app inbox updates live. FCM push is layered on top later
   * by the mobile-targeted consumer once we ship the device-token endpoint.
   */
  async sendToUser(
    userId: string,
    template: NotificationTemplate,
    data?: Record<string, unknown>,
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
    return notification;
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

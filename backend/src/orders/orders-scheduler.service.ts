import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

/**
 * Background scheduler for `scheduledFor` orders. Every 5 minutes it scans
 * for parked orders whose preparation window opens within the store's
 * configured lead time (default 2 h before the customer's chosen time) and
 * emits an `order.due_soon` realtime event so the merchant's screen surfaces
 * them at the top.
 *
 * Idempotent: relies on the `dueSoonNotifiedAt` column to avoid spamming the
 * same order — set the first time the order crosses the threshold.
 */
@Injectable()
export class OrdersSchedulerService {
  private readonly logger = new Logger(OrdersSchedulerService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
  ) {}

  @Cron(CronExpression.EVERY_5_MINUTES)
  async surfaceDueSoonOrders(): Promise<void> {
    const now = new Date();
    // Find PENDING orders with `scheduledFor` set whose
    // (scheduledFor - store.preparationLeadMinutes) is in the past — i.e.
    // they should now be on the merchant's radar.
    const candidates = await this.prisma.order.findMany({
      where: {
        status: 'PENDING',
        scheduledFor: { not: null },
        dueSoonNotifiedAt: null,
      },
      include: {
        store: { select: { id: true, preparationLeadMinutes: true } },
      },
    });

    const ready = candidates.filter((o) => {
      if (!o.scheduledFor) return false;
      const lead = o.store.preparationLeadMinutes ?? 120;
      const dueAt = new Date(o.scheduledFor.getTime() - lead * 60_000);
      return dueAt <= now;
    });

    if (ready.length === 0) return;

    for (const order of ready) {
      await this.prisma.order.update({
        where: { id: order.id },
        data: { dueSoonNotifiedAt: now },
      });

      this.realtime.emit([`store:${order.storeId}`, `order:${order.id}`], 'order.due_soon', {
        orderId: order.id,
        code: order.code,
        scheduledFor: order.scheduledFor!.toISOString(),
        at: now.toISOString(),
      });
    }

    this.logger.log(`Surfaced ${ready.length} scheduled order(s) as due-soon`);
  }
}

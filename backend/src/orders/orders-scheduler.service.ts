import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

import { AWAITING_ONLINE_PAYMENT, OrdersService } from './orders.service';

/** How long an unpaid online checkout may sit before it is reaped. 9Pay's
 *  payment link dies after ~15 min, so 30 min is already generous. */
const UNPAID_ONLINE_EXPIRY_MINUTES = 30;

/** The reaper only touches orders created after this feature shipped.
 *  Without the floor, the first ticks would mass-cancel months of legacy
 *  stranded checkouts (incl. old PayOS rows): stale stock injected into
 *  TODAY'S live counters and every affected customer emailed about an
 *  ancient order. Legacy rows stay hidden from the board (same predicate)
 *  and are cleaned up manually. */
const UNPAID_REAP_FLOOR = new Date('2026-08-20T00:00:00.000Z');

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
    private readonly orders: OrdersService,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * Reaps online checkouts the customer never paid (bailed on the 9Pay page
   * and maybe re-ordered — the abandoned twin must not linger). Restores
   * stock/coupon/points/gift card, voids the payment, cancels the order and
   * tells the customer. `cancelUnpayableOrder` aborts by itself if a capture
   * raced in, so a just-paid order can never be reaped.
   */
  @Cron(CronExpression.EVERY_5_MINUTES)
  async expireUnpaidOnlineOrders(): Promise<void> {
    const cutoff = new Date(Date.now() - UNPAID_ONLINE_EXPIRY_MINUTES * 60_000);
    const stale = await this.prisma.order.findMany({
      where: { ...AWAITING_ONLINE_PAYMENT, createdAt: { lt: cutoff, gte: UNPAID_REAP_FLOOR } },
      select: { id: true, code: true, customerId: true, storeId: true },
      take: 50,
    });
    for (const order of stale) {
      try {
        await this.orders.cancelUnpayableOrder(order.id, 'Tự huỷ: quá hạn thanh toán online');
        this.realtime.emit(
          [`order:${order.id}`, `user:${order.customerId}`],
          'order.status_changed',
          {
            orderId: order.id,
            code: order.code,
            fromStatus: 'PENDING',
            toStatus: 'CANCELLED',
            at: new Date().toISOString(),
          },
        );
        await this.notifications.sendToUser(
          order.customerId,
          {
            type: 'order.payment_expired',
            title: 'Đơn hàng đã huỷ',
            body: `Đơn ${order.code} đã huỷ vì chưa được thanh toán. Bạn có thể đặt lại bất cứ lúc nào.`,
          },
          { orderId: order.id, code: order.code },
        );
        this.logger.log(`Expired unpaid online order ${order.code}`);
      } catch (e) {
        this.logger.warn(`Could not expire ${order.code}: ${(e as Error).message}`);
      }
    }
  }

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

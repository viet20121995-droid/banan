import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Background jobs for the "Sản xuất" (MES) section. Two schedules, both routed to
 * every active kitchen-role user through the shared NotificationsService:
 *  - a daily 07:00 (ICT) digest of near/expired lots + overdue MOs, and
 *  - a frequent sweep that pushes one urgent notification per new QC alert.
 */
@Injectable()
export class ManufacturingSchedulerService {
  private readonly logger = new Logger(ManufacturingSchedulerService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Daily HSD + overdue-MO digest, at 07:00 VN time. */
  @Cron('0 0 7 * * *', { timeZone: 'Asia/Ho_Chi_Minh' })
  async dailyDigest(): Promise<void> {
    const soon = new Date(Date.now() + 3 * 86400000); // expiring within 3 days (or already past)
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);

    const [lots, overdue] = await Promise.all([
      // Lots at/near expiry that still hold stock at STOCK.
      this.prisma.mfgLot.count({
        where: {
          expiryDate: { not: null, lte: soon },
          quants: { some: { location: { code: 'STOCK' }, quantity: { gt: 0 } } },
        },
      }),
      // MOs planned before today and still open.
      this.prisma.mfgOrder.count({
        where: {
          scheduledDate: { lt: today },
          state: { in: ['DRAFT', 'CONFIRMED', 'PROGRESS'] },
        },
      }),
    ]);

    const parts: string[] = [];
    if (lots > 0) parts.push(`${lots} lô sắp/hết hạn`);
    if (overdue > 0) parts.push(`${overdue} lệnh quá hạn`);
    if (parts.length === 0) return;

    await this.notifications.notifyKitchenRoles(
      { type: 'mfg.daily_digest', title: 'Nhắc việc sản xuất', body: parts.join(' · ') },
      { lots, overdue },
    );
    this.logger.log(`MES daily digest sent: ${parts.join(', ')}`);
  }

  /**
   * Push one notification per not-yet-notified QC alert, then stamp notifiedAt so
   * it fires exactly once. ponytail: single VPS instance, so no claim-before-send
   * lock — a mid-loop crash would re-notify a few alerts on the next sweep, which
   * is harmless. Add a guarded claim if this ever runs multi-instance.
   */
  @Cron(CronExpression.EVERY_10_MINUTES)
  async qcAlertSweep(): Promise<void> {
    const fresh = await this.prisma.mfgQualityAlert.findMany({
      where: { notifiedAt: null, stage: 'NEW' },
      select: { id: true, title: true, moId: true },
    });
    if (fresh.length === 0) return;

    for (const a of fresh) {
      await this.notifications.notifyKitchenRoles(
        { type: 'mfg.qc_alert', title: 'Cảnh báo QC', body: a.title },
        a.moId ? { moId: a.moId } : undefined,
      );
    }
    await this.prisma.mfgQualityAlert.updateMany({
      where: { id: { in: fresh.map((a) => a.id) } },
      data: { notifiedAt: new Date() },
    });
    this.logger.log(`MES QC alerts notified: ${fresh.length}`);
  }
}

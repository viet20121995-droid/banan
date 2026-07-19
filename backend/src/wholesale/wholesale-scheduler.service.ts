import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Daily receivable sweep: OPEN/PARTIAL past their due date flip to OVERDUE —
 * so the admin "Quá hạn" filter shows exactly the accounts the order-blocking
 * gate is already refusing — and both sides get told: every admin (to chase)
 * and the buyer (to pay).
 */
@Injectable()
export class WholesaleSchedulerService {
  private readonly logger = new Logger(WholesaleSchedulerService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  // 07:10 ICT daily — after the kitchen digest, before the workday.
  @Cron('0 10 7 * * *', { timeZone: 'Asia/Ho_Chi_Minh' })
  async sweepOverdue(): Promise<void> {
    const now = new Date();
    // Read-then-flip: the ids are needed for the notifications, and the
    // guarded updateMany keeps a concurrent payment from being clobbered
    // (a receivable paid between the read and the update no longer matches).
    const due = await this.prisma.wholesaleReceivable.findMany({
      where: {
        status: { in: ['OPEN', 'PARTIAL'] },
        dueDate: { not: null, lt: now },
      },
      include: {
        account: { select: { id: true, companyName: true, userId: true } },
        order: { select: { code: true } },
      },
    });
    if (due.length === 0) return;

    const flipped = await this.prisma.wholesaleReceivable.updateMany({
      where: {
        id: { in: due.map((r) => r.id) },
        status: { in: ['OPEN', 'PARTIAL'] },
      },
      data: { status: 'OVERDUE' },
    });
    this.logger.log(`Wholesale receivables overdue: ${flipped.count}`);

    const admins = await this.prisma.user.findMany({
      where: { role: 'ADMIN', isActive: true },
      select: { id: true },
    });
    const fmt = new Intl.NumberFormat('vi-VN');
    for (const r of due) {
      const remaining = Number(r.amountVnd.toString()) - Number(r.paidAmountVnd.toString());
      const body = `${r.account.companyName} · ${r.order.code} — còn ${fmt.format(remaining)} ₫, hạn ${r.dueDate!.toISOString().slice(0, 10)}`;
      for (const admin of admins) {
        await this.notifications.sendToUser(
          admin.id,
          { type: 'wholesale_overdue', title: 'Công nợ quá hạn', body },
          { receivableId: r.id },
          { email: false },
        );
      }
      await this.notifications.sendToUser(
        r.account.userId,
        {
          type: 'wholesale_overdue',
          title: 'Công nợ quá hạn',
          body: `Đơn ${r.order.code} còn ${fmt.format(remaining)} ₫ đã quá hạn thanh toán — đơn mới sẽ bị tạm khoá.`,
        },
        { receivableId: r.id },
      );
    }
  }
}

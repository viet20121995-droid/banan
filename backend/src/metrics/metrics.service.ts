import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { EmailService } from '../notifications/email.service';
import { DAILY_REPORT_EMAILS } from '../notifications/store-alert-emails';
import { PrismaService } from '../prisma/prisma.service';

// Vietnam has no DST, so a fixed +7 h offset is exact.
const HCM_OFFSET_MS = 7 * 3_600_000;
const DAY_MS = 86_400_000;

/** Midnight (Asia/Ho_Chi_Minh) of the day `daysAgo` days before `now`, as UTC. */
export function hcmDayStart(now: Date, daysAgo = 0): Date {
  const local = new Date(now.getTime() + HCM_OFFSET_MS);
  local.setUTCHours(0, 0, 0, 0);
  return new Date(local.getTime() - daysAgo * DAY_MS - HCM_OFFSET_MS);
}

function hcmDayLabel(dayStartUtc: Date): string {
  const local = new Date(dayStartUtc.getTime() + HCM_OFFSET_MS);
  const dd = String(local.getUTCDate()).padStart(2, '0');
  const mm = String(local.getUTCMonth() + 1).padStart(2, '0');
  return `${dd}/${mm}`;
}

@Injectable()
export class MetricsService {
  private readonly logger = new Logger(MetricsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly email: EmailService,
  ) {}

  /** Stores one storefront page-load beacon. */
  async recordVisit(visitorId: string): Promise<void> {
    await this.prisma.siteVisit.create({ data: { visitorId } });
  }

  /**
   * Daily traffic report at 08:00 VN time — visits (page loads) + unique
   * visitors per day for the last 7 full days, plus yesterday's order count.
   * Reuses the transactional email pipe; dry-runs when RESEND_API_KEY is
   * unset, and a failure only logs (the cron retries tomorrow).
   */
  @Cron('0 0 8 * * *', { timeZone: 'Asia/Ho_Chi_Minh' })
  async sendDailyReport(now = new Date()): Promise<void> {
    try {
      const lines = await this.buildReportLines(now);
      await this.email.sendStaffOrderAlert({
        to: [...DAILY_REPORT_EMAILS],
        subject: `Báo cáo truy cập website · ${hcmDayLabel(hcmDayStart(now, 1))}`,
        heading: 'Báo cáo truy cập website',
        lines,
      });
      // Retention: the report only ever reads 7 days back — keep 35 and let
      // the beacon table stay small forever.
      await this.prisma.siteVisit.deleteMany({
        where: { createdAt: { lt: hcmDayStart(now, 35) } },
      });
    } catch (err) {
      this.logger.error(`Daily traffic report failed: ${(err as Error).message}`);
    }
  }

  /** One line per day, newest first: "19/08: 123 lượt · 45 khách". */
  async buildReportLines(now: Date): Promise<string[]> {
    const days: { label: string; visits: number; uniques: number }[] = [];
    for (let ago = 1; ago <= 7; ago++) {
      const gte = hcmDayStart(now, ago);
      const lt = new Date(gte.getTime() + DAY_MS);
      const [visits, uniques] = await Promise.all([
        this.prisma.siteVisit.count({ where: { createdAt: { gte, lt } } }),
        this.prisma.siteVisit
          .groupBy({ by: ['visitorId'], where: { createdAt: { gte, lt } } })
          .then((rows) => rows.length),
      ]);
      days.push({ label: hcmDayLabel(gte), visits, uniques });
    }

    const yGte = hcmDayStart(now, 1);
    const yLt = new Date(yGte.getTime() + DAY_MS);
    // REFUNDED excluded too: a cancelled order flips to REFUNDED once the
    // provider refund settles — without it the same order counts or not
    // depending on refund timing vs the 08:00 cron.
    const ordersYesterday = await this.prisma.order.count({
      where: {
        createdAt: { gte: yGte, lt: yLt },
        source: 'WEB',
        status: { notIn: ['CANCELLED', 'REFUNDED'] },
      },
    });

    const y = days[0];
    const totals = days.reduce(
      (acc, d) => ({ visits: acc.visits + d.visits, uniques: acc.uniques + d.uniques }),
      { visits: 0, uniques: 0 },
    );
    return [
      `Hôm qua (${y.label}): ${y.visits} lượt truy cập · ${y.uniques} khách · ${ordersYesterday} đơn hàng web`,
      '7 ngày gần nhất:',
      ...days.map((d) => `${d.label}: ${d.visits} lượt · ${d.uniques} khách`),
      `Tổng 7 ngày: ${totals.visits} lượt truy cập`,
    ];
  }
}

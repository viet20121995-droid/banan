import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { EmailService } from '../notifications/email.service';
import { DAILY_REPORT_EMAILS } from '../notifications/store-alert-emails';
import { PrismaService } from '../prisma/prisma.service';

import type { SiteEventInput } from './event-batch';

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

  /** Stores a validated behaviour batch (see `parseEventBatch`). */
  async recordEvents(
    visitorId: string,
    sessionId: string,
    events: SiteEventInput[],
  ): Promise<void> {
    await this.prisma.siteEvent.createMany({
      data: events.map((e) => ({
        visitorId,
        sessionId,
        type: e.type,
        path: e.path,
        label: e.label ?? null,
        value: e.value ?? null,
        device: e.device ?? null,
        referrer: e.referrer ?? null,
      })),
    });
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
      const lines = [
        ...(await this.buildReportLines(now)),
        '',
        ...(await this.buildBehaviourLines(now)),
      ];
      await this.email.sendStaffOrderAlert({
        to: [...DAILY_REPORT_EMAILS],
        subject: `Báo cáo truy cập website · ${hcmDayLabel(hcmDayStart(now, 1))}`,
        heading: 'Báo cáo truy cập website',
        lines,
      });
      // Retention: the report only ever reads 7 days back — keep 35 and let
      // the beacon tables stay small forever.
      const cutoff = hcmDayStart(now, 35);
      await this.prisma.siteVisit.deleteMany({ where: { createdAt: { lt: cutoff } } });
      await this.prisma.siteEvent.deleteMany({ where: { createdAt: { lt: cutoff } } });
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

  /**
   * "Hotjar-lite" section for yesterday (VN day): sessions, page views,
   * scroll depth, devices, top pages, the shopping funnel, clicks and
   * traffic sources — computed in one JS pass over the day's events (a few
   * thousand rows at most; no SQL rollups needed).
   */
  async buildBehaviourLines(now: Date): Promise<string[]> {
    const gte = hcmDayStart(now, 1);
    const lt = new Date(gte.getTime() + DAY_MS);
    const events = await this.prisma.siteEvent.findMany({
      where: { createdAt: { gte, lt } },
      select: {
        sessionId: true,
        type: true,
        path: true,
        value: true,
        device: true,
        referrer: true,
      },
    });
    const header = `Hành vi trên website (${hcmDayLabel(gte)}) — Hotjar-lite:`;
    if (events.length === 0) {
      return [header, 'Chưa có dữ liệu hành vi (beacon mới bật hoặc không có lượt xem).'];
    }

    const sessions = new Set<string>();
    const pageViews = new Map<string, number>();
    let pageViewCount = 0;
    const scrollDepths: number[] = [];
    const clicks = new Map<string, number>();
    let clickCount = 0;
    const devices = new Map<string, number>();
    const referrers = new Map<string, number>();
    const productSessions = new Set<string>();
    const cartSessions = new Set<string>();
    const checkoutSessions = new Set<string>();
    const orderSessions = new Set<string>();
    for (const e of events) {
      sessions.add(e.sessionId);
      switch (e.type) {
        case 'page_view':
          pageViewCount++;
          pageViews.set(e.path, (pageViews.get(e.path) ?? 0) + 1);
          if (e.path.startsWith('/product/') || e.path.startsWith('/bundles/')) {
            productSessions.add(e.sessionId);
          }
          break;
        case 'scroll':
          if (e.value != null) scrollDepths.push(e.value);
          break;
        case 'click':
          clickCount++;
          clicks.set(e.path, (clicks.get(e.path) ?? 0) + 1);
          break;
        case 'add_to_cart':
          cartSessions.add(e.sessionId);
          break;
        case 'checkout':
          checkoutSessions.add(e.sessionId);
          break;
        case 'order_placed':
          orderSessions.add(e.sessionId);
          break;
        case 'session_start':
          devices.set(e.device ?? 'khác', (devices.get(e.device ?? 'khác') ?? 0) + 1);
          referrers.set(e.referrer ?? 'direct', (referrers.get(e.referrer ?? 'direct') ?? 0) + 1);
          break;
      }
    }

    const n = sessions.size || 1;
    const pct = (part: number, whole: number) =>
      whole === 0 ? 0 : Math.round((part / whole) * 100);
    const top = (m: Map<string, number>, k: number) =>
      [...m.entries()].sort((a, b) => b[1] - a[1]).slice(0, k);
    const avgScroll = scrollDepths.length
      ? Math.round(scrollDepths.reduce((a, b) => a + b, 0) / scrollDepths.length)
      : null;
    const deepScroll = scrollDepths.filter((v) => v >= 50).length;
    const deviceLine = top(devices, 3)
      .map(
        ([d, c]) =>
          `${{ mobile: 'điện thoại', tablet: 'tablet', desktop: 'máy tính' }[d] ?? d} ${pct(
            c,
            [...devices.values()].reduce((a, b) => a + b, 0),
          )}%`,
      )
      .join(' · ');

    return [
      header,
      `${sessions.size} phiên · ${pageViewCount} lượt xem trang · ${(pageViewCount / n).toFixed(1)} trang/phiên${deviceLine ? ` · ${deviceLine}` : ''}`,
      avgScroll == null
        ? 'Cuộn trang: chưa có dữ liệu'
        : `Cuộn trang: trung bình ${avgScroll}% · ${pct(deepScroll, scrollDepths.length)}% lượt xem cuộn quá nửa trang`,
      `Phễu mua hàng: ${sessions.size} phiên → ${productSessions.size} xem sản phẩm → ${cartSessions.size} thêm giỏ → ${checkoutSessions.size} vào thanh toán → ${orderSessions.size} đặt hàng (${pct(orderSessions.size, sessions.size)}%)`,
      `Click: ${clickCount} lượt${
        clicks.size
          ? ` · nhiều nhất: ${top(clicks, 3)
              .map(([p, c]) => `${p} (${c})`)
              .join(', ')}`
          : ''
      }`,
      `Trang xem nhiều: ${
        top(pageViews, 5)
          .map(([p, c]) => `${p} (${c})`)
          .join(', ') || '—'
      }`,
      `Nguồn truy cập: ${
        top(referrers, 5)
          .map(
            ([r, c]) =>
              `${r} ${pct(
                c,
                [...referrers.values()].reduce((a, b) => a + b, 0),
              )}%`,
          )
          .join(' · ') || '—'
      }`,
    ];
  }
}

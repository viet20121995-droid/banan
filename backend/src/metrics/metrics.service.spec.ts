import { MetricsService, hcmDayStart } from './metrics.service';

describe('hcmDayStart', () => {
  it('maps a UTC instant to the Vietnam calendar day it belongs to', () => {
    // 2026-08-20 02:00 UTC = 09:00 in Hồ Chí Minh → that day starts 19th 17:00 UTC.
    const now = new Date('2026-08-20T02:00:00.000Z');
    expect(hcmDayStart(now, 0).toISOString()).toBe('2026-08-19T17:00:00.000Z');
    expect(hcmDayStart(now, 1).toISOString()).toBe('2026-08-18T17:00:00.000Z');
  });

  it('18:30 UTC already belongs to the NEXT Vietnam day', () => {
    // 2026-08-19 18:30 UTC = 2026-08-20 01:30 HCM.
    const now = new Date('2026-08-19T18:30:00.000Z');
    expect(hcmDayStart(now, 0).toISOString()).toBe('2026-08-19T17:00:00.000Z');
  });
});

describe('MetricsService.buildReportLines', () => {
  function makeService(opts: { visits?: number; uniques?: number; orders?: number } = {}) {
    const visitCount = jest.fn().mockResolvedValue(opts.visits ?? 12);
    const visitGroupBy = jest
      .fn()
      .mockResolvedValue(
        Array.from({ length: opts.uniques ?? 5 }, (_, i) => ({ visitorId: `v${i}` })),
      );
    const visitDeleteMany = jest.fn().mockResolvedValue({ count: 0 });
    const orderCount = jest.fn().mockResolvedValue(opts.orders ?? 3);
    const prisma = {
      siteVisit: { count: visitCount, groupBy: visitGroupBy, deleteMany: visitDeleteMany },
      order: { count: orderCount },
    };
    const email = { sendStaffOrderAlert: jest.fn().mockResolvedValue(undefined) };
    const svc = new MetricsService(prisma as never, email as never);
    return { svc, visitCount, visitGroupBy, visitDeleteMany, orderCount, email };
  }

  const now = new Date('2026-08-20T02:00:00.000Z'); // 09:00 HCM, 20/08

  it('summarises yesterday + the last 7 VN days', async () => {
    const m = makeService();
    const lines = await m.svc.buildReportLines(now);

    expect(lines[0]).toBe('Hôm qua (19/08): 12 lượt truy cập · 5 khách · 3 đơn hàng web');
    // 7 per-day lines between the header and the total.
    expect(lines).toHaveLength(1 + 1 + 7 + 1);
    expect(lines[2]).toBe('19/08: 12 lượt · 5 khách');
    expect(lines[lines.length - 1]).toBe(`Tổng 7 ngày: ${12 * 7} lượt truy cập`);
    // Yesterday's window is the full VN day in UTC.
    const firstWhere = m.visitCount.mock.calls[0][0].where.createdAt;
    expect((firstWhere.gte as Date).toISOString()).toBe('2026-08-18T17:00:00.000Z');
    expect((firstWhere.lt as Date).toISOString()).toBe('2026-08-19T17:00:00.000Z');
  });

  it('order count excludes cancelled/refunded and non-web orders', async () => {
    const m = makeService();
    await m.svc.buildReportLines(now);
    const where = m.orderCount.mock.calls[0][0].where;
    expect(where.source).toBe('WEB');
    expect(where.status).toEqual({ notIn: ['CANCELLED', 'REFUNDED'] });
  });

  it('sendDailyReport emails the fixed recipients and never throws', async () => {
    const m = makeService();
    await m.svc.sendDailyReport(now);
    expect(m.email.sendStaffOrderAlert).toHaveBeenCalledTimes(1);
    const args = m.email.sendStaffOrderAlert.mock.calls[0][0];
    expect(args.to).toEqual(['operationmanager@banancakes.com', 'ducnguyen@vestav.com']);
    expect(args.subject).toBe('Báo cáo truy cập website · 19/08');
    // Retention: rows older than 35 VN days are pruned after the send.
    const del = m.visitDeleteMany.mock.calls[0][0].where.createdAt;
    expect((del.lt as Date).toISOString()).toBe('2026-07-15T17:00:00.000Z');

    // A prisma outage inside the report must not crash the cron.
    m.visitCount.mockRejectedValue(new Error('db down'));
    await expect(m.svc.sendDailyReport(now)).resolves.toBeUndefined();
  });
});

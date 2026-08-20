// `nanoid` is ESM-only and pulled in transitively (scheduler → orders →
// payments → momo). Stub it so Jest can load the module graph.
jest.mock('nanoid', () => ({ customAlphabet: () => () => 'test-id' }));

import { OrdersSchedulerService } from './orders-scheduler.service';

describe('OrdersSchedulerService.expireUnpaidOnlineOrders', () => {
  function makeService(opts: {
    stale: Array<{ id: string; code: string; customerId: string; storeId: string }>;
    cancelError?: Error;
  }) {
    const findMany = jest.fn().mockResolvedValue(opts.stale);
    const prisma = { order: { findMany } };
    const realtime = { emit: jest.fn() };
    const orders = {
      cancelUnpayableOrder: opts.cancelError
        ? jest.fn().mockRejectedValue(opts.cancelError)
        : jest.fn().mockResolvedValue(undefined),
    };
    const notifications = { sendToUser: jest.fn().mockResolvedValue(undefined) };
    const svc = new OrdersSchedulerService(
      prisma as never,
      realtime as never,
      orders as never,
      notifications as never,
    );
    return { svc, findMany, realtime, orders, notifications };
  }

  const stale = [{ id: 'o1', code: 'BAN-1', customerId: 'c1', storeId: 's1' }];

  it('cancels the stale order, emits status_changed and tells the customer', async () => {
    const m = makeService({ stale });
    await m.svc.expireUnpaidOnlineOrders();

    expect(m.orders.cancelUnpayableOrder).toHaveBeenCalledWith(
      'o1',
      expect.stringContaining('quá hạn thanh toán'),
    );
    expect(m.realtime.emit).toHaveBeenCalledTimes(1);
    const [rooms, event, payload] = m.realtime.emit.mock.calls[0];
    expect(rooms).toEqual(['order:o1', 'user:c1']);
    expect(event).toBe('order.status_changed');
    expect(payload).toMatchObject({ orderId: 'o1', toStatus: 'CANCELLED' });
    expect(m.notifications.sendToUser).toHaveBeenCalledWith(
      'c1',
      expect.objectContaining({ type: 'order.payment_expired' }),
      { orderId: 'o1', code: 'BAN-1' },
    );
  });

  it('only reaps orders older than the expiry cutoff', async () => {
    const m = makeService({ stale: [] });
    const before = Date.now();
    await m.svc.expireUnpaidOnlineOrders();
    const where = m.findMany.mock.calls[0][0].where;
    // Predicate must target PENDING + unpaid gateway orders (shared filter).
    expect(where.status).toBe('PENDING');
    const cutoff = (where.createdAt.lt as Date).getTime();
    // 30 minutes ago, give or take test runtime.
    expect(before - cutoff).toBeGreaterThanOrEqual(30 * 60_000 - 1000);
    expect(before - cutoff).toBeLessThan(31 * 60_000);
    // Floor: legacy pre-feature checkouts are never mass-reaped.
    expect((where.createdAt.gte as Date).toISOString()).toBe('2026-08-20T00:00:00.000Z');
  });

  it('a cancel failure (e.g. paid meanwhile) is logged, not fatal — customer NOT told', async () => {
    const m = makeService({ stale, cancelError: new Error('paid meanwhile') });
    await expect(m.svc.expireUnpaidOnlineOrders()).resolves.toBeUndefined();
    expect(m.notifications.sendToUser).not.toHaveBeenCalled();
    expect(m.realtime.emit).not.toHaveBeenCalled();
  });
});

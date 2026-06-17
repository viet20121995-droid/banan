// `nanoid` is ESM-only and pulled in transitively (payments → momo). Stub it
// so Jest can load the module graph; applyCapture never touches it.
jest.mock('nanoid', () => ({ customAlphabet: () => () => 'test-id' }));

import { PaymentsService } from './payments.service';

/**
 * Service-level spec for the centralised online-capture path. This is where
 * the money-safety invariants live, so it gets direct coverage before any real
 * provider is switched on:
 *   - only INITIATED / AUTHORIZED → CAPTURED
 *   - VOIDED / REFUNDED / FAILED / CAPTURED are never resurrected
 *   - the provider-reported paid amount must equal Payment.amount
 *   - emit + notify happen only on a real state change (updateMany count > 0)
 */

type PaymentRow = {
  id: string;
  orderId: string;
  provider: string;
  providerRef: string;
  amount: number | string;
  status: string;
};

function payment(status: string, amount: number | string = 50000): PaymentRow {
  return {
    id: 'p1',
    orderId: 'o1',
    provider: 'PAYOS',
    providerRef: 'PR-1',
    amount,
    status,
  };
}

function makeService(opts: {
  payment?: PaymentRow | null;
  updateCount?: number;
  order?: Record<string, unknown> | null;
}) {
  const findFirst = jest.fn().mockResolvedValue(opts.payment ?? null);
  const updateMany = jest
    .fn()
    .mockResolvedValue({ count: opts.updateCount ?? 1 });
  const orderFindUnique = jest.fn().mockResolvedValue(
    opts.order === undefined
      ? {
          id: 'o1',
          code: 'BAN-1',
          customerId: 'c1',
          storeId: 's1',
          kitchenId: null,
        }
      : opts.order,
  );
  const refundFindFirst = jest.fn().mockResolvedValue(null);
  const refundCreate = jest.fn().mockResolvedValue({});
  const prisma = {
    payment: { findFirst, updateMany },
    order: { findUnique: orderFindUnique },
    refund: { findFirst: refundFindFirst, create: refundCreate },
  };
  const realtime = { emit: jest.fn() };
  const notifications = { sendToUser: jest.fn().mockResolvedValue(undefined) };
  const noop = {} as never;
  // ctor: prisma, cash, stripe, payos, momo, realtime, notifications
  const svc = new PaymentsService(
    prisma as never,
    noop,
    noop,
    noop,
    noop,
    realtime as never,
    notifications as never,
  );
  return {
    svc,
    findFirst,
    updateMany,
    orderFindUnique,
    realtime,
    notifications,
    refundCreate,
  };
}

const capture = (
  svc: PaymentsService,
  paidAmountVnd: number | null | undefined,
) =>
  svc.applyCapture({
    provider: 'PAYOS' as never,
    providerRef: 'PR-1',
    paidAmountVnd,
    payload: { ok: true },
  });

describe('PaymentsService.applyCapture', () => {
  it('INITIATED + correct amount → CAPTURED, emits + notifies', async () => {
    const m = makeService({ payment: payment('INITIATED') });
    await capture(m.svc, 50000);

    expect(m.updateMany).toHaveBeenCalledTimes(1);
    const arg = m.updateMany.mock.calls[0][0];
    expect(arg.where.status.in).toEqual(['INITIATED', 'AUTHORIZED']);
    expect(arg.data.status).toBe('CAPTURED');
    expect(m.realtime.emit).toHaveBeenCalledTimes(1);
    expect(m.realtime.emit.mock.calls[0][1]).toBe('order.payment_captured');
    expect(m.notifications.sendToUser).toHaveBeenCalledTimes(1);
    expect(m.notifications.sendToUser.mock.calls[0][0]).toBe('c1');
  });

  it('AUTHORIZED + correct amount → CAPTURED', async () => {
    const m = makeService({ payment: payment('AUTHORIZED') });
    await capture(m.svc, 50000);
    expect(m.updateMany).toHaveBeenCalledTimes(1);
    expect(m.updateMany.mock.calls[0][0].data.status).toBe('CAPTURED');
    expect(m.realtime.emit).toHaveBeenCalledTimes(1);
  });

  it('VOIDED + correct amount → no update, no emit, no notify', async () => {
    const m = makeService({ payment: payment('VOIDED') });
    await capture(m.svc, 50000);
    expect(m.updateMany).not.toHaveBeenCalled();
    expect(m.realtime.emit).not.toHaveBeenCalled();
    expect(m.notifications.sendToUser).not.toHaveBeenCalled();
  });

  it('REFUNDED + correct amount → no update, no emit, no notify', async () => {
    const m = makeService({ payment: payment('REFUNDED') });
    await capture(m.svc, 50000);
    expect(m.updateMany).not.toHaveBeenCalled();
    expect(m.realtime.emit).not.toHaveBeenCalled();
    expect(m.notifications.sendToUser).not.toHaveBeenCalled();
  });

  it('FAILED + correct amount → no update (not resurrected)', async () => {
    const m = makeService({ payment: payment('FAILED') });
    await capture(m.svc, 50000);
    expect(m.updateMany).not.toHaveBeenCalled();
    expect(m.realtime.emit).not.toHaveBeenCalled();
  });

  it('CAPTURED (replayed webhook) + correct amount → no update, no emit, no notify', async () => {
    const m = makeService({ payment: payment('CAPTURED') });
    await capture(m.svc, 50000);
    // Idempotency: a duplicate/late webhook must not re-emit or re-notify.
    expect(m.updateMany).not.toHaveBeenCalled();
    expect(m.realtime.emit).not.toHaveBeenCalled();
    expect(m.notifications.sendToUser).not.toHaveBeenCalled();
  });

  it('INITIATED + WRONG amount → no update, no emit, no notify', async () => {
    const m = makeService({ payment: payment('INITIATED', 50000) });
    await capture(m.svc, 9999);
    expect(m.updateMany).not.toHaveBeenCalled();
    expect(m.realtime.emit).not.toHaveBeenCalled();
    expect(m.notifications.sendToUser).not.toHaveBeenCalled();
  });

  it('unknown providerRef → ignored (no update/emit/notify)', async () => {
    const m = makeService({ payment: null });
    await capture(m.svc, 50000);
    expect(m.updateMany).not.toHaveBeenCalled();
    expect(m.realtime.emit).not.toHaveBeenCalled();
    expect(m.notifications.sendToUser).not.toHaveBeenCalled();
  });

  it('updateMany count = 0 (lost race) → no emit, no notify', async () => {
    const m = makeService({ payment: payment('INITIATED'), updateCount: 0 });
    await capture(m.svc, 50000);
    expect(m.updateMany).toHaveBeenCalledTimes(1);
    expect(m.realtime.emit).not.toHaveBeenCalled();
    expect(m.notifications.sendToUser).not.toHaveBeenCalled();
  });

  it('amount not provided → capture proceeds (amount check skipped)', async () => {
    const m = makeService({ payment: payment('INITIATED') });
    await capture(m.svc, null);
    expect(m.updateMany).toHaveBeenCalledTimes(1);
    expect(m.realtime.emit).toHaveBeenCalledTimes(1);
  });

  it('late capture on a CANCELLED order → auto-opens a refund, no "captured" notify', async () => {
    const m = makeService({
      payment: payment('INITIATED'),
      order: { id: 'o1', status: 'CANCELLED', storeId: 's1' },
    });
    await capture(m.svc, 50000);
    expect(m.updateMany).toHaveBeenCalledTimes(1); // payment still captured (truth)
    expect(m.refundCreate).toHaveBeenCalledTimes(1); // auto-refund opened
    expect(m.refundCreate.mock.calls[0][0].data.status).toBe('REQUESTED');
    // No celebratory customer notification on a cancelled order.
    expect(m.notifications.sendToUser).not.toHaveBeenCalled();
  });
});

type RefundRow = {
  id: string;
  orderId: string;
  paymentId: string | null;
  status: string;
};

function makeRefundService(opts: {
  refund?: RefundRow | null;
  refundUpdateCount?: number;
}) {
  const refundFindFirst = jest.fn().mockResolvedValue(opts.refund ?? null);
  const refundUpdateMany = jest
    .fn()
    .mockResolvedValue({ count: opts.refundUpdateCount ?? 1 });
  const orderUpdateMany = jest.fn().mockResolvedValue({ count: 1 });
  const paymentUpdateMany = jest.fn().mockResolvedValue({ count: 1 });
  const prisma = {
    refund: { findFirst: refundFindFirst, updateMany: refundUpdateMany },
    order: { updateMany: orderUpdateMany },
    payment: { updateMany: paymentUpdateMany },
  };
  const realtime = { emit: jest.fn() };
  const notifications = { sendToUser: jest.fn() };
  const noop = {} as never;
  const svc = new PaymentsService(
    prisma as never,
    noop,
    noop,
    noop,
    noop,
    realtime as never,
    notifications as never,
  );
  return {
    svc,
    refundFindFirst,
    refundUpdateMany,
    orderUpdateMany,
    paymentUpdateMany,
    realtime,
  };
}

const settle = (svc: PaymentsService) =>
  svc.applyRefundSettled({
    provider: 'STRIPE' as never,
    providerRef: 're_1',
    payload: { ok: true },
  });

describe('PaymentsService.applyRefundSettled', () => {
  it('PROCESSING refund → COMPLETED, mirrors order + payment to REFUNDED, emits', async () => {
    const m = makeRefundService({
      refund: { id: 'r1', orderId: 'o1', paymentId: 'p1', status: 'PROCESSING' },
    });
    await settle(m.svc);

    expect(m.refundUpdateMany).toHaveBeenCalledTimes(1);
    expect(m.refundUpdateMany.mock.calls[0][0].data.status).toBe('COMPLETED');
    expect(m.orderUpdateMany).toHaveBeenCalledTimes(1);
    expect(m.orderUpdateMany.mock.calls[0][0].data.status).toBe('REFUNDED');
    expect(m.paymentUpdateMany).toHaveBeenCalledTimes(1);
    expect(m.paymentUpdateMany.mock.calls[0][0].data.status).toBe('REFUNDED');
    expect(m.realtime.emit).toHaveBeenCalledTimes(1);
    expect(m.realtime.emit.mock.calls[0][1]).toBe('refund.updated');
  });

  it('no in-flight refund (replay / unknown ref) → no-op', async () => {
    const m = makeRefundService({ refund: null });
    await settle(m.svc);
    expect(m.refundUpdateMany).not.toHaveBeenCalled();
    expect(m.orderUpdateMany).not.toHaveBeenCalled();
    expect(m.paymentUpdateMany).not.toHaveBeenCalled();
    expect(m.realtime.emit).not.toHaveBeenCalled();
  });

  it('lost race (updateMany count = 0) → no order/payment mirror, no emit', async () => {
    const m = makeRefundService({
      refund: { id: 'r1', orderId: 'o1', paymentId: 'p1', status: 'APPROVED' },
      refundUpdateCount: 0,
    });
    await settle(m.svc);
    expect(m.refundUpdateMany).toHaveBeenCalledTimes(1);
    expect(m.orderUpdateMany).not.toHaveBeenCalled();
    expect(m.paymentUpdateMany).not.toHaveBeenCalled();
    expect(m.realtime.emit).not.toHaveBeenCalled();
  });

  it('refund without paymentId → order mirrored, payment update skipped', async () => {
    const m = makeRefundService({
      refund: { id: 'r1', orderId: 'o1', paymentId: null, status: 'PROCESSING' },
    });
    await settle(m.svc);
    expect(m.orderUpdateMany).toHaveBeenCalledTimes(1);
    expect(m.paymentUpdateMany).not.toHaveBeenCalled();
    expect(m.realtime.emit).toHaveBeenCalledTimes(1);
  });
});

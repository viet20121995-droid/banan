// `nanoid` is ESM-only and pulled in transitively (refunds → payments → momo).
// Stub it so Jest can load the module graph; it's not exercised here.
jest.mock('nanoid', () => ({ customAlphabet: () => () => 'test-id' }));

import { Prisma } from '@prisma/client';

import { RefundsService } from './refunds.service';

/**
 * Locks the refund-request idempotency contract:
 *  - returns an existing in-flight refund instead of opening a second;
 *  - creates exactly one when none exists;
 *  - standalone (non-tx) create catches the partial-unique P2002 and returns
 *    the winner (race with the late-capture auto-refund);
 *  - inside an interactive tx it must NOT swallow the violation (that would
 *    poison the caller's transaction).
 */
function makeService(refundMock: {
  findFirst: jest.Mock;
  create: jest.Mock;
}) {
  const prisma = { refund: refundMock };
  const realtime = { emit: jest.fn() };
  const noop = {} as never;
  const svc = new RefundsService(prisma as never, noop, realtime as never);
  return { svc, realtime, refundMock };
}

const args = {
  order: { id: 'o1' } as never,
  payment: { id: 'p1', amount: new Prisma.Decimal(1000) } as never,
  reason: 'Order cancelled',
  requestedById: 'system',
};

const p2002 = new Prisma.PrismaClientKnownRequestError('dup', {
  code: 'P2002',
  clientVersion: '5.22.0',
});

describe('RefundsService.createRequestTx', () => {
  it('creates exactly one refund when none exists (created=true)', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    const create = jest.fn().mockResolvedValue({ id: 'r1' });
    const { svc } = makeService({ findFirst, create });
    const res = await svc.createRequestTx(
      { refund: { findFirst, create } } as never,
      args,
    );
    expect(res.created).toBe(true);
    expect(create).toHaveBeenCalledTimes(1);
  });

  it('returns the existing in-flight refund without creating a second', async () => {
    const findFirst = jest.fn().mockResolvedValue({ id: 'r-existing' });
    const create = jest.fn();
    const { svc } = makeService({ findFirst, create });
    const res = await svc.createRequestTx(
      { refund: { findFirst, create } } as never,
      args,
    );
    expect(res).toEqual({ refund: { id: 'r-existing' }, created: false });
    expect(create).not.toHaveBeenCalled();
  });

  it('inside an interactive tx, a unique violation propagates (no catch)', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    const create = jest.fn().mockRejectedValue(p2002);
    const { svc } = makeService({ findFirst, create });
    await expect(
      svc.createRequestTx({ refund: { findFirst, create } } as never, {
        ...args,
        inInteractiveTx: true,
      }),
    ).rejects.toBe(p2002);
  });
});

describe('RefundsService.createRequest (standalone)', () => {
  it('catches the partial-unique P2002 and returns the race winner, no emit', async () => {
    // 1st findFirst (pre-create) → none; create → P2002; 2nd findFirst → winner.
    const findFirst = jest
      .fn()
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ id: 'r-winner' });
    const create = jest.fn().mockRejectedValue(p2002);
    const { svc, realtime } = makeService({ findFirst, create });
    const refund = await svc.createRequest(args);
    expect(refund).toEqual({ id: 'r-winner' });
    expect(realtime.emit).not.toHaveBeenCalled(); // not newly created → no emit
  });

  it('emits when it actually creates the refund', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    const create = jest.fn().mockResolvedValue({
      id: 'r1',
      orderId: 'o1',
      status: 'REQUESTED',
      amount: new Prisma.Decimal(1000),
    });
    const { svc, realtime } = makeService({ findFirst, create });
    await svc.createRequest(args);
    expect(realtime.emit).toHaveBeenCalledTimes(1);
  });
});

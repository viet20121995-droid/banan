import { BadRequestException } from '@nestjs/common';

import { LoyaltyService } from './loyalty.service';

// Stateful mock: the balance mutates as updates apply, and reads return the
// current value — so the atomic-increment / guarded-decrement flow in
// recordEvent (update/updateMany then re-read) behaves like the real DB.
function makeService(balance: number, opts: { decrementBlocked?: boolean } = {}) {
  let current = balance;
  const tx = {
    user: {
      findUniqueOrThrow: jest.fn(() => Promise.resolve({ pointsBalance: current })),
      update: jest.fn(({ data }: { data: { pointsBalance?: { increment?: number } } }) => {
        const inc = data?.pointsBalance?.increment;
        if (inc !== undefined) current += inc;
        return Promise.resolve({ pointsBalance: current });
      }),
      // Guarded decrement: applies only when the balance covers it (gte).
      updateMany: jest.fn(
        ({ where, data }: { where: { pointsBalance?: { gte?: number } }; data: { pointsBalance?: { increment?: number } } }) => {
          const gte = where?.pointsBalance?.gte;
          if (opts.decrementBlocked || (gte !== undefined && current < gte)) {
            return Promise.resolve({ count: 0 });
          }
          const inc = data?.pointsBalance?.increment;
          if (inc !== undefined) current += inc;
          return Promise.resolve({ count: 1 });
        },
      ),
    },
    loyaltyEvent: {
      create: jest
        .fn()
        .mockImplementation(({ data }) =>
          Promise.resolve({ ...data, id: 'e1' }),
        ),
    },
  };
  const prisma = {
    user: {
      findUniqueOrThrow: jest.fn(() => Promise.resolve({ pointsBalance: current })),
    },
    $transaction: jest.fn((cb: (t: unknown) => unknown) => cb(tx)),
  };
  return { svc: new LoyaltyService(prisma as never), tx };
}

describe('LoyaltyService.adminAdjust', () => {
  it('rejects a zero / non-integer delta', async () => {
    const { svc } = makeService(100);
    await expect(
      svc.adminAdjust({ userId: 'u1', delta: 0, reason: 'x' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects an adjustment that would go negative', async () => {
    const { svc } = makeService(30);
    await expect(
      svc.adminAdjust({ userId: 'u1', delta: -50, reason: 'refund' }),
    ).rejects.toMatchObject({
      response: { code: 'LOYALTY_NEGATIVE_BALANCE' },
    });
  });

  it('records a positive adjustment and updates the balance', async () => {
    const { svc, tx } = makeService(100);
    const ev = await svc.adminAdjust({
      userId: 'u1',
      delta: 25,
      reason: 'birthday gift',
    });
    expect(ev.delta).toBe(25);
    expect(ev.balanceAfter).toBe(125);
    expect(ev.type).toBe('ADJUSTMENT');
    // Balance is applied as an atomic increment (not an absolute write).
    expect(tx.user.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ pointsBalance: { increment: 25 } }),
      }),
    );
  });

  it('negative adjust uses a guarded decrement — throws if the balance no longer covers it (race)', async () => {
    // Pre-check passes (balance 100 + (-10) >= 0), but the atomic conditional
    // decrement fails (simulating a concurrent drain) → must reject, not go
    // negative.
    const { svc, tx } = makeService(100, { decrementBlocked: true });
    await expect(
      svc.adminAdjust({ userId: 'u1', delta: -10, reason: 'goodwill clawback' }),
    ).rejects.toMatchObject({ response: { code: 'LOYALTY_NEGATIVE_BALANCE' } });
    // Used the guarded updateMany, not an unconditional update.
    expect(tx.user.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ pointsBalance: { gte: 10 } }),
      }),
    );
  });
});

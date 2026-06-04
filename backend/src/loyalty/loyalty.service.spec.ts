import { BadRequestException } from '@nestjs/common';

import { LoyaltyService } from './loyalty.service';

function makeService(balance: number) {
  const tx = {
    user: {
      findUniqueOrThrow: jest.fn().mockResolvedValue({
        pointsBalance: balance,
      }),
      update: jest.fn().mockResolvedValue({}),
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
      findUniqueOrThrow: jest
        .fn()
        .mockResolvedValue({ pointsBalance: balance }),
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
    expect(tx.user.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ pointsBalance: 125 }),
      }),
    );
  });
});

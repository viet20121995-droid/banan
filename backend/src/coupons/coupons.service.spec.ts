import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { CouponsService } from './coupons.service';

function baseCoupon(over: Partial<Record<string, unknown>> = {}) {
  return {
    id: 'c1',
    code: 'SAVE10',
    type: 'PERCENT',
    value: new Prisma.Decimal(10),
    minSubtotal: null,
    startsAt: new Date(Date.now() - 86_400_000),
    endsAt: new Date(Date.now() + 86_400_000),
    maxRedemptions: null,
    redemptions: 0,
    perUserLimit: 0,
    isActive: true,
    storeId: null,
    ...over,
  };
}

function makeService(coupon: unknown, redemptionCount = 0) {
  const prisma = {
    coupon: { findUnique: jest.fn().mockResolvedValue(coupon) },
    couponRedemption: {
      count: jest.fn().mockResolvedValue(redemptionCount),
    },
  };
  return new CouponsService(prisma as never);
}

describe('CouponsService.validate', () => {
  const args = {
    code: 'save10',
    subtotalVnd: 200_000,
    deliveryFeeVnd: 20_000,
    userId: 'u1',
  };

  it('rejects an unknown / inactive coupon', async () => {
    await expect(
      makeService(null).validate(args),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      makeService(baseCoupon({ isActive: false })).validate(args),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects an expired coupon', async () => {
    const expired = baseCoupon({
      startsAt: new Date(Date.now() - 2 * 86_400_000),
      endsAt: new Date(Date.now() - 86_400_000),
    });
    await expect(
      makeService(expired).validate(args),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a coupon scoped to another store', async () => {
    const svc = makeService(baseCoupon({ storeId: 'store-A' }));
    await expect(
      svc.validate({ ...args, storeId: 'store-B' }),
    ).rejects.toMatchObject({
      response: { code: 'COUPON_WRONG_STORE' },
    });
  });

  it('allows a chain-wide coupon at any store', async () => {
    const svc = makeService(baseCoupon({ storeId: null }));
    const r = await svc.validate({ ...args, storeId: 'store-B' });
    expect(r.discountVnd).toBe(20_000); // 10% of 200k
  });

  it('computes PERCENT / FIXED / FREE_DELIVERY discounts', async () => {
    expect(
      (await makeService(baseCoupon()).validate(args)).discountVnd,
    ).toBe(20_000);

    const fixed = makeService(
      baseCoupon({ type: 'FIXED', value: new Prisma.Decimal(50_000) }),
    );
    expect((await fixed.validate(args)).discountVnd).toBe(50_000);

    const ship = makeService(baseCoupon({ type: 'FREE_DELIVERY' }));
    const r = await ship.validate(args);
    expect(r.discountVnd).toBe(20_000);
    expect(r.appliesToDelivery).toBe(true);
  });

  it('enforces the per-user redemption limit', async () => {
    const svc = makeService(baseCoupon({ perUserLimit: 1 }), 1);
    await expect(svc.validate(args)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('enforces a minimum subtotal', async () => {
    const svc = makeService(
      baseCoupon({ minSubtotal: new Prisma.Decimal(500_000) }),
    );
    await expect(svc.validate(args)).rejects.toMatchObject({
      response: { code: 'COUPON_MIN_SUBTOTAL' },
    });
  });
});

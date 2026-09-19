import { PromotionsService } from './promotions.service';

/**
 * recordUsage is the authoritative campaign-cap enforcement (evaluate only
 * reads counters). A per-campaign advisory lock serialises redemptions of the
 * same campaign in the order tx; these lock the re-check + increment behaviour.
 */
function makeTx(opts: { campaign: Record<string, unknown> | null; userCount?: number }) {
  const executeRaw = jest.fn().mockResolvedValue(1);
  const findUnique = jest.fn().mockResolvedValue(opts.campaign);
  const count = jest.fn().mockResolvedValue(opts.userCount ?? 0);
  const create = jest.fn().mockResolvedValue({});
  const update = jest.fn().mockResolvedValue({});
  const tx = {
    $executeRaw: executeRaw,
    campaign: { findUnique, update },
    campaignRedemption: { count, create },
  };
  return { tx, executeRaw, count, create, update };
}

const svc = () => new PromotionsService({} as never);
const run = (tx: unknown) =>
  svc().recordUsage({
    campaignIds: ['cam1'],
    userId: 'u1',
    orderId: 'o1',
    tx: tx as never,
  });

describe('PromotionsService.recordUsage (authoritative, race-safe)', () => {
  it('takes a per-campaign advisory lock, then records + increments usedCount', async () => {
    const m = makeTx({
      campaign: { usageLimit: 100, perUserLimit: 1, usedCount: 5 },
    });
    await run(m.tx);
    expect(m.executeRaw).toHaveBeenCalledTimes(1);
    expect(m.create).toHaveBeenCalledTimes(1);
    expect(m.update).toHaveBeenCalledWith({
      where: { id: 'cam1' },
      data: { usedCount: { increment: 1 } },
    });
  });

  it('throws CAMPAIGN_LIMIT_REACHED at the global cap (no record)', async () => {
    const m = makeTx({
      campaign: { usageLimit: 100, perUserLimit: null, usedCount: 100 },
    });
    await expect(run(m.tx)).rejects.toMatchObject({
      response: { code: 'CAMPAIGN_LIMIT_REACHED' },
    });
    expect(m.create).not.toHaveBeenCalled();
  });

  it('throws CAMPAIGN_USER_LIMIT when the per-user cap is reached', async () => {
    const m = makeTx({
      campaign: { usageLimit: null, perUserLimit: 1, usedCount: 3 },
      userCount: 1,
    });
    await expect(run(m.tx)).rejects.toMatchObject({
      response: { code: 'CAMPAIGN_USER_LIMIT' },
    });
    expect(m.create).not.toHaveBeenCalled();
  });

  it('skips a campaign that no longer exists without throwing', async () => {
    const m = makeTx({ campaign: null });
    await run(m.tx);
    expect(m.create).not.toHaveBeenCalled();
  });
});

/**
 * evaluate(): gift-with-purchase + birthday-cake exclusion. Prisma is mocked
 * at the query level; the engine's arithmetic is what's under test.
 */
function makeEvalService(campaigns: Record<string, unknown>[]) {
  const prisma = {
    product: {
      findMany: jest.fn(
        ({
          select,
          where,
        }: {
          select: Record<string, unknown>;
          where: { id: { in: string[] } };
        }) => {
          const rows = [
            {
              id: 'cake',
              name: 'Bánh sinh nhật',
              categoryId: 'c-bday',
              category: { isBirthdayCakeCategory: true },
            },
            {
              id: 'mochi',
              name: 'Mochi',
              categoryId: 'c-mochi',
              category: { isBirthdayCakeCategory: false },
            },
            {
              id: 'flan',
              name: 'Creme Flan',
              categoryId: 'c-pud',
              category: { isBirthdayCakeCategory: false },
            },
          ];
          const hit = rows.filter((r) => where.id.in.includes(r.id));
          return Promise.resolve(select.name ? hit.map(({ id, name }) => ({ id, name })) : hit);
        },
      ),
    },
    campaign: { findMany: jest.fn().mockResolvedValue(campaigns) },
    campaignRedemption: { groupBy: jest.fn().mockResolvedValue([]) },
    user: { findUnique: jest.fn().mockResolvedValue({ birthday: null, membershipTier: 'BRONZE' }) },
    order: {
      aggregate: jest.fn().mockResolvedValue({ _count: { _all: 0 }, _max: { createdAt: null } }),
    },
  };
  return new PromotionsService(prisma as never);
}

const GIFT = {
  id: 'gift',
  name: 'Đơn từ 250k tặng flan',
  type: 'GIFT_WITH_PURCHASE',
  isActive: true,
  config: { minSubtotal: 250_000, productIds: ['flan'], excludeBirthdayCakes: true },
  usageLimit: null,
  usedCount: 0,
  perUserLimit: null,
};
const FIRST = {
  id: 'first',
  name: 'Đơn đầu -15%',
  type: 'FIRST_ORDER',
  isActive: true,
  config: { kind: 'PERCENT', value: 15, minSubtotal: 300_000, excludeBirthdayCakes: true },
  usageLimit: null,
  usedCount: 0,
  perUserLimit: 1,
};

describe('PromotionsService.evaluate — gift with purchase + birthday exclusion', () => {
  it('frees the gift unit once the paid amount (gift excluded) reaches the minimum', async () => {
    const r = await makeEvalService([GIFT]).evaluate({
      lines: [
        { productId: 'mochi', quantity: 1, lineTotalVnd: 250_000 },
        { productId: 'flan', quantity: 1, lineTotalVnd: 55_000 },
      ],
      subtotalVnd: 305_000,
    });
    expect(r.discountVnd).toBe(55_000);
    expect(r.hints).toEqual([]);
  });

  it('a 250k cart that includes the gift pays under the minimum → no gift, hint for the rest', async () => {
    const r = await makeEvalService([GIFT]).evaluate({
      lines: [
        { productId: 'mochi', quantity: 1, lineTotalVnd: 195_000 },
        { productId: 'flan', quantity: 1, lineTotalVnd: 55_000 },
      ],
      subtotalVnd: 250_000,
    });
    expect(r.discountVnd).toBe(0);
    expect(r.hints).toMatchObject([{ campaignId: 'gift', shortVnd: 55_000 }]);
  });

  it('does not count a birthday cake toward the minimum, and hints when no gift is in the cart', async () => {
    const r = await makeEvalService([GIFT]).evaluate({
      lines: [
        { productId: 'cake', quantity: 1, lineTotalVnd: 400_000 },
        { productId: 'mochi', quantity: 1, lineTotalVnd: 100_000 },
      ],
      subtotalVnd: 500_000,
    });
    expect(r.discountVnd).toBe(0);
    expect(r.hints).toMatchObject([
      { campaignId: 'gift', shortVnd: 150_000, giftProducts: [{ id: 'flan', name: 'Creme Flan' }] },
    ]);
  });

  it('a gift product in a cart under the minimum still yields a hint', async () => {
    const r = await makeEvalService([GIFT]).evaluate({
      lines: [{ productId: 'flan', quantity: 1, lineTotalVnd: 55_000 }],
      subtotalVnd: 55_000,
    });
    expect(r.discountVnd).toBe(0);
    expect(r.hints).toMatchObject([{ campaignId: 'gift', shortVnd: 250_000 }]);
  });

  it('first-order 15% ignores birthday-cake lines; campaigns never stack — the best one wins', async () => {
    const r = await makeEvalService([GIFT, FIRST]).evaluate({
      lines: [
        { productId: 'cake', quantity: 1, lineTotalVnd: 500_000 },
        { productId: 'mochi', quantity: 2, lineTotalVnd: 300_000 },
        { productId: 'flan', quantity: 1, lineTotalVnd: 55_000 },
      ],
      subtotalVnd: 855_000,
      customerId: 'u1',
    });
    // First order: 15% of (855k − 500k cake) = 53 250. Gift: flan 55k free.
    // Only the larger one applies.
    expect(r.applied.map((a) => [a.id, a.discountVnd])).toEqual([['gift', 55_000]]);
    expect(r.discountVnd).toBe(55_000);

    const r2 = await makeEvalService([GIFT, FIRST]).evaluate({
      lines: [
        { productId: 'mochi', quantity: 4, lineTotalVnd: 600_000 },
        { productId: 'flan', quantity: 1, lineTotalVnd: 55_000 },
      ],
      subtotalVnd: 655_000,
      customerId: 'u1',
    });
    // 15% of 655k = 98 250 beats the 55k flan.
    expect(r2.applied.map((a) => [a.id, a.discountVnd])).toEqual([['first', 98_250]]);
  });

  it('only website orders count toward "first order"', async () => {
    const svc = makeEvalService([FIRST]);
    await svc.evaluate({
      lines: [{ productId: 'mochi', quantity: 1, lineTotalVnd: 400_000 }],
      subtotalVnd: 400_000,
      customerId: 'u1',
    });
    const prisma = (svc as unknown as { prisma: { order: { aggregate: jest.Mock } } }).prisma;
    expect(prisma.order.aggregate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { customerId: 'u1', source: 'WEB', status: { not: 'CANCELLED' } },
      }),
    );
  });

  it('first-order under the minimum yields a hint with the missing amount', async () => {
    const r = await makeEvalService([FIRST]).evaluate({
      lines: [{ productId: 'mochi', quantity: 1, lineTotalVnd: 200_000 }],
      subtotalVnd: 200_000,
      customerId: 'u1',
    });
    expect(r.discountVnd).toBe(0);
    expect(r.hints).toMatchObject([{ campaignId: 'first', shortVnd: 100_000 }]);
  });
});

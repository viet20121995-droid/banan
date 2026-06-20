import { Prisma } from '@prisma/client';

import { BundlesService } from './bundles.service';

/**
 * revalidateForProducts deactivates combos that a product edit just made
 * unfulfillable. isBundleStillValid mirrors assertItemsValid's rules against the
 * combo's CURRENT persisted items, so we feed combos shaped like the
 * BUNDLE_INCLUDE payload and assert which get deactivated.
 */
const dec = (n: number) => new Prisma.Decimal(n);

function combo(
  id: string,
  priceVnd: number,
  opts: { available?: boolean; flavorPick?: number; days?: number[] } = {},
) {
  return {
    id,
    priceVnd,
    items: [
      {
        quantity: 1,
        variant: { priceDelta: dec(0) },
        product: {
          isAvailable: opts.available ?? true,
          flavorPickCount: opts.flavorPick ?? 0,
          availableDaysOfWeek: opts.days ?? [],
          basePrice: dec(60000),
          variants: [{ id: 'v', priceDelta: dec(0) }],
        },
      },
      {
        quantity: 1,
        variant: { priceDelta: dec(0) },
        product: {
          isAvailable: true,
          flavorPickCount: 0,
          availableDaysOfWeek: [],
          basePrice: dec(60000),
          variants: [{ id: 'w', priceDelta: dec(0) }],
        },
      },
    ],
  };
}

describe('BundlesService.revalidateForProducts (deactivate combos broken by a product edit)', () => {
  function svcWith(bundles: unknown[]) {
    const tx = {
      bundle: {
        findMany: jest.fn().mockResolvedValue(bundles),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      $executeRaw: jest.fn().mockResolvedValue(0),
    };
    const svc = new BundlesService({} as never); // method uses tx, not this.prisma
    return { svc, tx };
  }

  it('deactivates a combo whose price now exceeds the à-la-carte sum', async () => {
    const { svc, tx } = svcWith([combo('b1', 200000)]); // 200k > 120k regular
    const out = await svc.revalidateForProducts(tx as never, ['p1']);
    expect(out).toEqual(['b1']);
    expect(tx.bundle.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['b1'] } },
      data: { isActive: false },
    });
  });

  it('keeps a still-valid combo (price ≤ sum)', async () => {
    const { svc, tx } = svcWith([combo('b1', 100000)]); // 100k ≤ 120k
    const out = await svc.revalidateForProducts(tx as never, ['p1']);
    expect(out).toEqual([]);
    expect(tx.bundle.updateMany).not.toHaveBeenCalled();
  });

  it('deactivates when a constituent became unavailable or a flavour-pick', async () => {
    const { svc, tx } = svcWith([
      combo('b1', 100000, { available: false }),
      combo('b2', 100000, { flavorPick: 3 }),
      combo('b3', 100000), // still valid
    ]);
    const out = await svc.revalidateForProducts(tx as never, ['p1']);
    expect(out).toEqual(['b1', 'b2']);
    // Took a per-combo lock for each deactivation.
    expect(tx.$executeRaw).toHaveBeenCalledTimes(2);
  });

  it('is a no-op for an empty product list', async () => {
    const { svc, tx } = svcWith([]);
    const out = await svc.revalidateForProducts(tx as never, []);
    expect(out).toEqual([]);
    expect(tx.bundle.findMany).not.toHaveBeenCalled();
  });
});

import { Prisma } from '@prisma/client';

import { BundlesService } from './bundles.service';

/**
 * The combo-integrity protocol splits into two primitives:
 *   - lockActiveBundlesForProducts: advisory-lock (sorted) the combos a product
 *     edit touches, BEFORE mutating product/variant rows (deadlock-safe order).
 *   - deactivateInvalidBundles: re-evaluate those (locked) combos and deactivate
 *     the ones a product edit just made unfulfillable.
 * isBundleStillValid mirrors assertItemsValid, so we feed combos shaped like the
 * BUNDLE_INCLUDE payload and assert which get deactivated.
 */
const dec = (n: number) => new Prisma.Decimal(n);

function combo(
  id: string,
  priceVnd: number,
  opts: {
    available?: boolean;
    variantAvailable?: boolean;
    flavorPick?: number;
    days?: number[];
  } = {},
) {
  return {
    id,
    priceVnd,
    items: [
      {
        quantity: 1,
        variant: { priceDelta: dec(0), isAvailable: opts.variantAvailable ?? true },
        product: {
          isAvailable: opts.available ?? true,
          flavorPickCount: opts.flavorPick ?? 0,
          availableDaysOfWeek: opts.days ?? [],
          basePrice: dec(60000),
          variants: [{ id: 'v', priceDelta: dec(0), isAvailable: true }],
        },
      },
      {
        quantity: 1,
        variant: { priceDelta: dec(0), isAvailable: true },
        product: {
          isAvailable: true,
          flavorPickCount: 0,
          availableDaysOfWeek: [],
          basePrice: dec(60000),
          variants: [{ id: 'w', priceDelta: dec(0), isAvailable: true }],
        },
      },
    ],
  };
}

describe('BundlesService.deactivateInvalidBundles', () => {
  function svcWith(bundles: unknown[]) {
    const tx = {
      bundle: {
        findMany: jest.fn().mockResolvedValue(bundles),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
    };
    const svc = new BundlesService({} as never); // uses tx, not this.prisma
    return { svc, tx };
  }

  it('deactivates combos that no longer validate, keeps valid ones', async () => {
    const { svc, tx } = svcWith([
      combo('b1', 200000), // price 200k > 120k sum → invalid
      combo('b2', 100000, { available: false }), // product unavailable
      combo('b3', 100000, { variantAvailable: false }), // variant unavailable
      combo('b4', 100000, { flavorPick: 3 }), // flavour-pick
      combo('b5', 100000, { days: [1] }), // day-conflict with item 2 (any-day)? no
      combo('b6', 100000), // valid
    ]);
    const out = await svc.deactivateInvalidBundles(tx as never, [
      'b1',
      'b2',
      'b3',
      'b4',
      'b5',
      'b6',
    ]);
    // b5: item1 sells only Mon, item2 any day → common day = Mon → still valid.
    expect(out).toEqual(['b1', 'b2', 'b3', 'b4']);
    expect(tx.bundle.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['b1', 'b2', 'b3', 'b4'] } },
      data: { isActive: false },
    });
  });

  it('keeps a still-valid combo (no updateMany)', async () => {
    const { svc, tx } = svcWith([combo('b1', 100000)]);
    expect(await svc.deactivateInvalidBundles(tx as never, ['b1'])).toEqual([]);
    expect(tx.bundle.updateMany).not.toHaveBeenCalled();
  });

  it('is a no-op for empty input', async () => {
    const { svc, tx } = svcWith([]);
    expect(await svc.deactivateInvalidBundles(tx as never, [])).toEqual([]);
    expect(tx.bundle.findMany).not.toHaveBeenCalled();
  });
});

describe('BundlesService.lockActiveBundlesForProducts', () => {
  it('locks each active combo containing the products, in sorted id order', async () => {
    const tx = {
      bundle: {
        findMany: jest.fn().mockResolvedValue([{ id: 'b3' }, { id: 'b1' }, { id: 'b2' }]),
      },
      $executeRaw: jest.fn().mockResolvedValue(0),
    };
    const svc = new BundlesService({} as never);
    const out = await svc.lockActiveBundlesForProducts(tx as never, ['p1']);
    expect(out).toEqual(['b1', 'b2', 'b3']);
    expect(tx.$executeRaw).toHaveBeenCalledTimes(3);
  });

  it('is a no-op for an empty product list', async () => {
    const tx = { bundle: { findMany: jest.fn() }, $executeRaw: jest.fn() };
    const svc = new BundlesService({} as never);
    expect(await svc.lockActiveBundlesForProducts(tx as never, [])).toEqual([]);
    expect(tx.bundle.findMany).not.toHaveBeenCalled();
  });
});

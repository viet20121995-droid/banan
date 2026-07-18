import {
  avcoAfterReceipt,
  computeRatios,
  convertQty,
  expiryDate,
  isExpiringWithin,
  toBase,
} from './mfg-math';

const G = { category: 'weight', factor: 1 }; // gram
const KG = { category: 'weight', factor: 1000 }; // kilogram
const PIECE = { category: 'unit', factor: 1 };

describe('convertQty', () => {
  it('scales within a category', () => {
    expect(convertQty(2, KG, G)).toBe(2000);
    expect(convertQty(500, G, KG)).toBe(0.5);
    expect(convertQty(3, G, G)).toBe(3);
  });

  it('refuses to cross categories — a weight is not a count', () => {
    expect(() => convertQty(1, KG, PIECE)).toThrow(/incompatible/);
  });

  it('rejects a zero target factor rather than dividing by zero', () => {
    expect(() => convertQty(1, KG, { category: 'weight', factor: 0 })).toThrow();
  });
});

describe('toBase', () => {
  it('reduces to the reference unit', () => {
    expect(toBase(1.5, KG)).toBe(1500);
    expect(toBase(4, PIECE)).toBe(4);
  });
});

describe('computeRatios (baker percentage)', () => {
  it('is 100% on the flour and scales the rest against it', () => {
    // 1000g flour, 650g water, 20g salt → hydration 65%, salt 2%.
    const r = computeRatios([
      { baseWeight: 1000, isBasis: true },
      { baseWeight: 650 },
      { baseWeight: 20 },
    ]);
    expect(r[0]).toBe(100);
    expect(r[1]).toBe(65);
    expect(r[2]).toBe(2);
  });

  it('falls back to total weight when no basis line is flagged', () => {
    // 300 + 100 = 400 total → 75% / 25%.
    const r = computeRatios([{ baseWeight: 300 }, { baseWeight: 100 }]);
    expect(r[0]).toBe(75);
    expect(r[1]).toBe(25);
  });

  it('yields zeros instead of dividing by zero on an empty basis', () => {
    expect(computeRatios([{ baseWeight: 0 }, { baseWeight: 0 }])).toEqual([0, 0]);
  });
});

describe('avcoAfterReceipt', () => {
  it('adopts the incoming cost when stock was empty', () => {
    expect(avcoAfterReceipt(0, 0, 100, 50)).toBe(50);
  });

  it('weights old and new by quantity', () => {
    // 100g @ 40 + 100g @ 60 → 50.
    expect(avcoAfterReceipt(100, 40, 100, 60)).toBe(50);
    // 300g @ 20 + 100g @ 60 → (6000+6000)/400 = 30.
    expect(avcoAfterReceipt(300, 20, 100, 60)).toBe(30);
  });

  it('does not move on a non-positive inflow (consumption is not a receipt)', () => {
    expect(avcoAfterReceipt(100, 40, 0, 999)).toBe(40);
    expect(avcoAfterReceipt(100, 40, -50, 999)).toBe(40);
  });

  it('keeps 2 decimals on the unit cost (a rollup must not shed đồng)', () => {
    // (100*10 + 100*11)/200 = 10.5 — a per-gram cost, not a till price.
    expect(avcoAfterReceipt(100, 10, 100, 11)).toBe(10.5);
    // Third decimal rounds to cents.
    expect(avcoAfterReceipt(3, 100, 1, 101)).toBe(100.25);
  });
});

describe('expiryDate', () => {
  it('adds the shelf life for a tracked product', () => {
    const mfg = new Date('2026-07-18T00:00:00Z');
    expect(expiryDate(mfg, true, 3)?.toISOString().slice(0, 10)).toBe('2026-07-21');
  });

  it('is null for a shelf-stable product', () => {
    expect(expiryDate(new Date(), false, 30)).toBeNull();
    expect(expiryDate(new Date(), true, 0)).toBeNull();
  });
});

describe('isExpiringWithin', () => {
  const now = new Date('2026-07-18T00:00:00Z');
  it('flags a lot inside the window', () => {
    expect(isExpiringWithin(new Date('2026-07-20'), 3, now)).toBe(true);
  });
  it('leaves a far-off lot alone', () => {
    expect(isExpiringWithin(new Date('2026-08-30'), 3, now)).toBe(false);
  });
  it('ignores an untracked lot', () => {
    expect(isExpiringWithin(null, 3, now)).toBe(false);
  });
});

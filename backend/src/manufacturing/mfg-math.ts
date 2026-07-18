/**
 * Pure manufacturing arithmetic. No Prisma, no I/O — everything here is a
 * function of its inputs so the money-and-quantity rules can be pinned down
 * with unit tests. Callers pass plain numbers; the service converts Prisma
 * Decimals in and out at the boundary.
 */

/** A unit of measure reduced to what conversion needs. */
export interface UomLike {
  category: string;
  /** Multiplier to the category's reference unit (grams for weight). */
  factor: number;
}

/**
 * Convert [qty] expressed in [from] into [to]. Only meaningful within one
 * category — a weight can't become a count — so a cross-category request is a
 * programming error, not a silent 0.
 */
export function convertQty(qty: number, from: UomLike, to: UomLike): number {
  if (from.category !== to.category) {
    throw new Error(`Cannot convert ${from.category} to ${to.category}: incompatible units`);
  }
  if (to.factor === 0) throw new Error('UoM factor cannot be zero');
  return (qty * from.factor) / to.factor;
}

/** [qty] in [uom] expressed in the category's reference unit (grams, pieces). */
export function toBase(qty: number, uom: UomLike): number {
  return qty * uom.factor;
}

/**
 * Baker's percentage for each line against a basis weight. Ratio =
 * lineBaseWeight / basisWeight × 100. The basis is the flour line when one is
 * flagged (classic baker's %), else the total of all lines ("hoặc tổng NVL").
 *
 * Inputs are already in the same base unit (grams). Returns ratios aligned to
 * [lines] by index. A zero basis yields zeros rather than dividing by zero.
 */
export function computeRatios(lines: { baseWeight: number; isBasis?: boolean }[]): number[] {
  const flour = lines.filter((l) => l.isBasis);
  const basis = flour.length
    ? flour.reduce((s, l) => s + l.baseWeight, 0)
    : lines.reduce((s, l) => s + l.baseWeight, 0);
  if (basis === 0) return lines.map(() => 0);
  return lines.map((l) => round4((l.baseWeight / basis) * 100));
}

/**
 * New weighted-average cost after receiving [inQty] at [inUnitCost] on top of
 * [onHandQty] valued at [avgCost]. This is AVCO: the running average only
 * moves on inflows, and receiving into an empty stock simply adopts the
 * incoming cost. Consumption (outflow) does NOT change it — callers must not
 * feed negative quantities here.
 */
export function avcoAfterReceipt(
  onHandQty: number,
  avgCost: number,
  inQty: number,
  inUnitCost: number,
): number {
  if (inQty <= 0) return avgCost;
  const total = onHandQty + inQty;
  if (total <= 0) return inUnitCost;
  // A UNIT cost (đồng per gram), not a customer price — it keeps 2 decimals so
  // a semi at 180.25đ/g doesn't shed a quarter đồng on every gram when it rolls
  // up into a finished good. Whole-đồng rounding is only for order totals.
  return roundCost((onHandQty * avgCost + inQty * inUnitCost) / total);
}

/**
 * Expiry for a lot made today. Null when the product isn't expiry-tracked, so
 * a shelf-stable item (packaging, dry goods) carries no false date.
 */
export function expiryDate(
  mfgDate: Date,
  useExpiration: boolean,
  expirationDays: number,
): Date | null {
  if (!useExpiration || expirationDays <= 0) return null;
  const d = new Date(mfgDate);
  d.setDate(d.getDate() + expirationDays);
  return d;
}

/** True when [expiry] falls on or before [asOf] + [withinDays]. */
export function isExpiringWithin(expiry: Date | null, withinDays: number, asOf: Date): boolean {
  if (expiry == null) return false;
  const threshold = new Date(asOf);
  threshold.setDate(threshold.getDate() + withinDays);
  return expiry.getTime() <= threshold.getTime();
}

/** Order-level totals land on a whole đồng — VND has no minor unit in the till. */
export function roundMoney(n: number): number {
  return Math.round(n);
}

/** Per-unit costs (đồng per gram) keep 2 decimals so rollups don't lose them. */
export function roundCost(n: number): number {
  return Math.round(n * 100) / 100;
}

/** Quantities in grams keep 3 decimals; anything finer is measurement noise. */
export function round3(n: number): number {
  return Math.round(n * 1000) / 1000;
}

function round4(n: number): number {
  return Math.round(n * 10000) / 10000;
}

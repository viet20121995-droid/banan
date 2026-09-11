import { Prisma } from '@prisma/client';

/// Pure aggregation helpers for the merchant reports — kept free of Prisma
/// queries so they can be unit-tested on plain arrays.

export function num(d: Prisma.Decimal | number | string | null | undefined): number {
  if (d === null || d === undefined) return 0;
  return Number(d.toString());
}

/// ISO date in ICT (UTC+7). Used so daily series matches the merchant's
/// calendar day, not the UTC day where 7am ICT would belong to "yesterday".
export function ictDay(d: Date): string {
  const ict = new Date(d.getTime() + 7 * 60 * 60 * 1000);
  return ict.toISOString().slice(0, 10);
}

export function ictDateTime(d: Date | null | undefined): string {
  if (!d) return '';
  const ict = new Date(d.getTime() + 7 * 60 * 60 * 1000);
  return ict.toISOString().slice(0, 16).replace('T', ' ');
}

export function ictHour(d: Date): number {
  return new Date(d.getTime() + 7 * 60 * 60 * 1000).getUTCHours();
}

/// 0 = Sunday … 6 = Saturday, in ICT.
export function ictWeekday(d: Date): number {
  return new Date(d.getTime() + 7 * 60 * 60 * 1000).getUTCDay();
}

const CANDLE_LABEL: Record<string, string> = {
  regular: 'Nến thường',
  spiral: 'Nến xoắn',
  number: 'Nến số',
};
const KEY_LABEL: Record<string, string> = {
  textOnCake: 'Chữ trên bánh',
  note: 'Ghi chú',
};

/// Human line for `OrderItem.personalization`: macaron sets store
/// `{ flavors: { Jasmine: 3, Lemon: 2 } }`; birthday cakes store the wizard
/// payload `{ textOnCake, candleType, candleCount, candleNumber, note }`.
export function describePersonalization(p: unknown): string {
  if (!p || typeof p !== 'object') return '';
  const obj = p as Record<string, unknown>;
  const parts: string[] = [];
  const flavors = obj.flavors;
  if (flavors && typeof flavors === 'object') {
    const f = Object.entries(flavors as Record<string, unknown>)
      .filter(([, n]) => Number(n) > 0)
      .map(([name, n]) => `${name}×${n}`);
    if (f.length) parts.push(f.join(', '));
  }
  if (typeof obj.candleType === 'string') {
    const type = CANDLE_LABEL[obj.candleType] ?? obj.candleType;
    const qty =
      obj.candleType === 'number'
        ? obj.candleNumber != null
          ? ` ${obj.candleNumber}`
          : ''
        : obj.candleCount != null
          ? ` ×${obj.candleCount}`
          : '';
    parts.push(`${type}${qty}`);
  }
  for (const [k, v] of Object.entries(obj)) {
    if (['flavors', 'candleType', 'candleCount', 'candleNumber'].includes(k)) continue;
    if (v === null || v === undefined || v === '' || v === false) continue;
    if (typeof v === 'object') continue;
    parts.push(`${KEY_LABEL[k] ?? k}: ${String(v)}`);
  }
  return parts.join(' · ');
}

export interface SalesItemInput {
  orderId: string;
  productId: string;
  productName: string;
  variantLabel: string | null;
  sku?: string | null;
  category?: string | null;
  quantity: number;
  lineTotal: Prisma.Decimal | number;
  personalization?: unknown;
}

export interface ProductSalesRow {
  productId: string;
  productName: string;
  variantLabel: string;
  sku: string;
  category: string;
  unitsSold: number;
  orders: number;
  revenue: number;
  /// Share of total item revenue in the period, 0–100.
  share: number;
}

/// One row per product × variant, sorted by revenue. `share` sums to ~100.
export function aggregateProductSales(items: SalesItemInput[], limit = 50): ProductSalesRow[] {
  const agg = new Map<string, ProductSalesRow & { orderIds: Set<string> }>();
  for (const i of items) {
    const key = `${i.productId}|${i.variantLabel ?? ''}`;
    const cur = agg.get(key) ?? {
      productId: i.productId,
      productName: i.productName,
      variantLabel: i.variantLabel ?? '',
      sku: i.sku ?? '',
      category: i.category ?? '',
      unitsSold: 0,
      orders: 0,
      revenue: 0,
      share: 0,
      orderIds: new Set<string>(),
    };
    cur.unitsSold += i.quantity;
    cur.revenue += num(i.lineTotal);
    cur.orderIds.add(i.orderId);
    agg.set(key, cur);
  }
  const total = Array.from(agg.values()).reduce((s, r) => s + r.revenue, 0);
  return Array.from(agg.values())
    .map(({ orderIds, ...r }) => ({
      ...r,
      orders: orderIds.size,
      share: total > 0 ? Math.round((r.revenue / total) * 1000) / 10 : 0,
    }))
    .sort((a, b) => b.revenue - a.revenue || b.unitsSold - a.unitsSold)
    .slice(0, limit);
}

export interface FlavorRow {
  productName: string;
  flavor: string;
  units: number;
}

/// Flavour picks inside composed sets ("Set of 5 Macarons" → Jasmine ×12…).
export function aggregateFlavors(items: SalesItemInput[]): FlavorRow[] {
  const agg = new Map<string, FlavorRow>();
  for (const i of items) {
    const p = i.personalization as Record<string, unknown> | null | undefined;
    const flavors = p?.flavors;
    if (!flavors || typeof flavors !== 'object') continue;
    for (const [flavor, n] of Object.entries(flavors as Record<string, unknown>)) {
      const count = Number(n) * i.quantity;
      if (!(count > 0)) continue;
      const key = `${i.productName}|${flavor}`;
      const cur = agg.get(key) ?? { productName: i.productName, flavor, units: 0 };
      cur.units += count;
      agg.set(key, cur);
    }
  }
  return Array.from(agg.values()).sort(
    (a, b) => a.productName.localeCompare(b.productName) || b.units - a.units,
  );
}

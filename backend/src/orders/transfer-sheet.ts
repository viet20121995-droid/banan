import type { Prisma } from '@prisma/client';

import { vnDayKey } from '../kitchen/kitchen-queue-where';

/**
 * The branch order book, as the kitchen fills it in: one sheet per delivery
 * day, one row per item, and per receiving branch the quantity the branch
 * asked for ("Đặt") next to what the kitchen ships ("Giao"). Pure — the
 * service fetches, this shapes.
 */

export interface TransferSheetLine {
  orderId: string;
  itemId: string;
  kind: 'item' | 'mfg';
  ordered: number;
  shipped: number;
}

export interface TransferSheetCell {
  ordered: number;
  shipped: number;
  /** The order lines behind the cell — a branch can have two orders for one day. */
  lines: TransferSheetLine[];
}

export interface TransferSheetRow {
  key: string;
  label: string;
  unit: string;
  isSupply: boolean;
  isDrinkIngredient: boolean;
  byStore: Record<string, TransferSheetCell>;
  ordered: number;
  shipped: number;
}

export interface TransferSheetDay {
  /** VN calendar day the goods are due, `yyyy-MM-dd`. */
  day: string;
  orders: Array<{ id: string; code: string; storeId: string; kitchenStatus: string | null }>;
  stores: Array<{ id: string; name: string }>;
  rows: TransferSheetRow[];
}

export interface TransferSheet {
  days: TransferSheetDay[];
}

type SheetOrder = {
  id: string;
  code: string;
  storeId: string;
  kitchenStatus: string | null;
  scheduledFor: Date | null;
  createdAt: Date;
  items: Array<{
    id: string;
    productName: string;
    variantLabel: string | null;
    quantity: number;
    orderedQty: number | null;
  }>;
  mfgItems: Array<{
    id: string;
    qty: Prisma.Decimal | number;
    orderedQty: Prisma.Decimal | number | null;
    mfgProduct: {
      code: string;
      nameVi: string;
      drinkIngredient: boolean;
      uom: { code: string };
    };
  }>;
  destinationStore: { id: string; name: string } | null;
  requestingStore: { id: string; name: string } | null;
};

/** The VN calendar day a transfer is due — unscheduled ones are due the day they were placed. */
export function transferDayKey(o: { scheduledFor: Date | null; createdAt: Date }): string {
  return vnDayKey(o.scheduledFor ?? o.createdAt);
}

/**
 * "Macaron (single) (Lemon)", not "Macaron (single) (Single · Lemon)";
 * "Creme Flan", not "Creme Flan (Default · Creme Flan)" — only the part of
 * the variant that tells rows apart.
 */
export function transferLineLabel(productName: string, variantLabel: string | null): string {
  const parts = (variantLabel ?? '')
    .split(' · ')
    .map((v) => v.trim())
    .filter((v) => v && !['Default', 'Single', 'Classic'].includes(v) && v !== productName);
  return parts.length ? `${productName} (${parts.join(' · ')})` : productName;
}

export function buildTransferSheet(orders: SheetOrder[]): TransferSheet {
  const days = new Map<string, TransferSheetDay & { rowMap: Map<string, TransferSheetRow> }>();
  for (const order of orders) {
    const key = transferDayKey(order);
    const day: TransferSheetDay & { rowMap: Map<string, TransferSheetRow> } = days.get(key) ?? {
      day: key,
      orders: [],
      stores: [],
      rows: [],
      rowMap: new Map(),
    };
    const store = order.destinationStore ?? order.requestingStore;
    const storeId = store?.id ?? order.storeId;
    if (!day.stores.some((s) => s.id === storeId)) {
      day.stores.push({ id: storeId, name: store?.name ?? 'Cửa hàng' });
    }
    day.orders.push({
      id: order.id,
      code: order.code,
      storeId,
      kitchenStatus: order.kitchenStatus,
    });

    const add = (
      rowKey: string,
      label: string,
      unit: string,
      kind: 'cake' | 'drink' | 'supply',
      line: TransferSheetLine,
    ) => {
      const row = day.rowMap.get(rowKey) ?? {
        key: rowKey,
        label,
        unit,
        isSupply: kind !== 'cake',
        isDrinkIngredient: kind === 'drink',
        byStore: {},
        ordered: 0,
        shipped: 0,
      };
      const cell = row.byStore[storeId] ?? { ordered: 0, shipped: 0, lines: [] };
      cell.ordered += line.ordered;
      cell.shipped += line.shipped;
      cell.lines.push(line);
      row.byStore[storeId] = cell;
      row.ordered += line.ordered;
      row.shipped += line.shipped;
      day.rowMap.set(rowKey, row);
    };
    for (const i of order.items) {
      const label = transferLineLabel(i.productName, i.variantLabel);
      add(`i:${label}`, label, 'cái', 'cake', {
        orderId: order.id,
        itemId: i.id,
        kind: 'item',
        ordered: i.orderedQty ?? i.quantity,
        shipped: i.quantity,
      });
    }
    for (const m of order.mfgItems) {
      const shipped = Number(m.qty);
      add(
        `m:${m.mfgProduct.code}`,
        `${m.mfgProduct.nameVi} (${m.mfgProduct.code})`,
        m.mfgProduct.uom.code,
        m.mfgProduct.drinkIngredient ? 'drink' : 'supply',
        {
          orderId: order.id,
          itemId: m.id,
          kind: 'mfg',
          ordered: m.orderedQty == null ? shipped : Number(m.orderedQty),
          shipped,
        },
      );
    }
    days.set(key, day);
  }

  // Cakes first, then the bar restock group, then everything else the
  // warehouse ships along.
  const rank = (r: { isSupply: boolean; isDrinkIngredient: boolean }) =>
    !r.isSupply ? 0 : r.isDrinkIngredient ? 1 : 2;
  return {
    days: [...days.values()]
      .sort((a, b) => a.day.localeCompare(b.day))
      .map(({ rowMap, ...day }) => ({
        ...day,
        stores: [...day.stores].sort((a, b) => a.name.localeCompare(b.name, 'vi')),
        rows: [...rowMap.values()].sort(
          (a, b) => rank(a) - rank(b) || a.label.localeCompare(b.label, 'vi'),
        ),
      })),
  };
}

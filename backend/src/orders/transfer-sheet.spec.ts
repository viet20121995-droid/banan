import { buildTransferSheet, transferDayKey, transferLineLabel } from './transfer-sheet';

const store = (id: string, name: string) => ({ id, name });

function order(over: {
  id: string;
  code: string;
  store: { id: string; name: string };
  scheduledFor: Date | null;
  createdAt?: Date;
  items?: Array<{
    id: string;
    productName: string;
    variantLabel?: string | null;
    quantity: number;
    orderedQty?: number | null;
  }>;
  mfgItems?: Array<{
    id: string;
    code: string;
    nameVi: string;
    qty: number;
    orderedQty?: number | null;
  }>;
}) {
  return {
    id: over.id,
    code: over.code,
    storeId: over.store.id,
    kitchenStatus: 'PENDING_ACK',
    scheduledFor: over.scheduledFor,
    createdAt: over.createdAt ?? new Date('2026-09-04T03:00:00Z'),
    items: (over.items ?? []).map((i) => ({
      variantLabel: null,
      orderedQty: null,
      ...i,
    })),
    mfgItems: (over.mfgItems ?? []).map((m) => ({
      id: m.id,
      qty: m.qty,
      orderedQty: m.orderedQty ?? null,
      mfgProduct: { code: m.code, nameVi: m.nameVi, drinkIngredient: false, uom: { code: 'kg' } },
    })),
    destinationStore: over.store,
    requestingStore: over.store,
  };
}

describe('transferLineLabel', () => {
  it('drops the size/flavor parts that say nothing', () => {
    expect(transferLineLabel('Creme Flan', 'Default · Creme Flan')).toBe('Creme Flan');
    expect(transferLineLabel('Macaron (single)', 'Single · Lemon')).toBe(
      'Macaron (single) (Lemon)',
    );
    expect(transferLineLabel('Strawberry Cake', '16cm · Classic')).toBe('Strawberry Cake (16cm)');
    expect(transferLineLabel('Nama', null)).toBe('Nama');
  });
});

describe('transferDayKey', () => {
  it('is the VN calendar day of the delivery, else of placement', () => {
    // 23:30Z = 06:30 VN next day
    expect(
      transferDayKey({ scheduledFor: new Date('2026-09-04T23:30:00Z'), createdAt: new Date() }),
    ).toBe('2026-09-05');
    expect(
      transferDayKey({ scheduledFor: null, createdAt: new Date('2026-09-04T18:00:00Z') }),
    ).toBe('2026-09-05');
  });
});

describe('buildTransferSheet', () => {
  const ts = store('s1', 'Banan – Trường Sa');
  const ltt = store('s2', 'Banan – Lê Thánh Tôn');

  it('one sheet per delivery day, rows merged across branches, ordered vs shipped', () => {
    const sheet = buildTransferSheet([
      order({
        id: 'o1',
        code: 'A',
        store: ts,
        scheduledFor: new Date('2026-09-04T23:30:00Z'),
        items: [
          {
            id: 'i1',
            productName: 'Creme Flan',
            variantLabel: 'Default · Creme Flan',
            quantity: 18,
          },
          { id: 'i2', productName: 'Mango Pudding', quantity: 1, orderedQty: 2 }, // kitchen cut 2 → 1
        ],
      }),
      order({
        id: 'o2',
        code: 'B',
        store: ltt,
        scheduledFor: new Date('2026-09-04T23:30:00Z'),
        items: [
          {
            id: 'i3',
            productName: 'Creme Flan',
            variantLabel: 'Default · Creme Flan',
            quantity: 12,
          },
        ],
        mfgItems: [{ id: 'm1', code: 'FH-L-001', nameVi: 'Sữa tươi', qty: 4 }],
      }),
      order({
        id: 'o3',
        code: 'C',
        store: ts,
        scheduledFor: new Date('2026-09-06T23:30:00Z'), // another day → its own sheet
        items: [{ id: 'i4', productName: 'Creme Flan', quantity: 5 }],
      }),
    ]);

    expect(sheet.days.map((d) => d.day)).toEqual(['2026-09-05', '2026-09-07']);
    const day = sheet.days[0];
    expect(day.orders.map((o) => o.code)).toEqual(['A', 'B']);
    // branches sorted by name
    expect(day.stores.map((s) => s.name)).toEqual(['Banan – Lê Thánh Tôn', 'Banan – Trường Sa']);
    // cakes before supplies, then by label
    expect(day.rows.map((r) => r.label)).toEqual([
      'Creme Flan',
      'Mango Pudding',
      'Sữa tươi (FH-L-001)',
    ]);

    const flan = day.rows[0];
    expect(flan.byStore.s1).toMatchObject({ ordered: 18, shipped: 18 });
    expect(flan.byStore.s2).toMatchObject({ ordered: 12, shipped: 12 });
    expect(flan.ordered).toBe(30);
    expect(flan.byStore.s1.lines[0]).toMatchObject({ orderId: 'o1', itemId: 'i1', kind: 'item' });

    const pudding = day.rows[1];
    expect(pudding.byStore.s1).toMatchObject({ ordered: 2, shipped: 1 });
    expect(pudding.ordered).toBe(2);
    expect(pudding.shipped).toBe(1);
    expect(pudding.byStore.s2).toBeUndefined();

    expect(day.rows[2]).toMatchObject({ unit: 'kg', isSupply: true });
    expect(day.rows[2].byStore.s2.lines[0]).toMatchObject({
      itemId: 'm1',
      kind: 'mfg',
      shipped: 4,
    });
  });

  it('two orders of one branch on one day add up in the same cell, both lines kept', () => {
    const sheet = buildTransferSheet([
      order({
        id: 'o1',
        code: 'A',
        store: ts,
        scheduledFor: new Date('2026-09-04T23:30:00Z'),
        items: [{ id: 'i1', productName: 'Creme Flan', quantity: 3 }],
      }),
      order({
        id: 'o2',
        code: 'B',
        store: ts,
        scheduledFor: new Date('2026-09-04T23:30:00Z'),
        items: [{ id: 'i2', productName: 'Creme Flan', quantity: 4 }],
      }),
    ]);
    const cell = sheet.days[0].rows[0].byStore.s1;
    expect(cell.ordered).toBe(7);
    expect(cell.lines.map((l) => l.itemId)).toEqual(['i1', 'i2']);
  });
});

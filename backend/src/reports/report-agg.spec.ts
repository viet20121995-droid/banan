import {
  aggregateFlavors,
  aggregateProductSales,
  describePersonalization,
  ictDay,
  ictHour,
} from './report-agg';

describe('report-agg', () => {
  const items = [
    {
      orderId: 'o1',
      productId: 'p1',
      productName: 'Macaron (single)',
      variantLabel: 'Single · Lemon',
      sku: 'VT00083',
      category: 'Macaron',
      quantity: 2,
      lineTotal: 76000,
    },
    {
      orderId: 'o2',
      productId: 'p1',
      productName: 'Macaron (single)',
      variantLabel: 'Single · Lemon',
      sku: 'VT00083',
      category: 'Macaron',
      quantity: 1,
      lineTotal: 38000,
    },
    {
      orderId: 'o2',
      productId: 'p1',
      productName: 'Macaron (single)',
      variantLabel: 'Single · Jasmine',
      sku: 'VT00683',
      category: 'Macaron',
      quantity: 1,
      lineTotal: 38000,
    },
    {
      orderId: 'o3',
      productId: 'p2',
      productName: 'Set of 5 Macarons',
      variantLabel: 'Default',
      quantity: 2,
      lineTotal: 380000,
      personalization: { flavors: { Jasmine: 3, Lemon: 2 } },
    },
  ];

  it('aggregates per product × variant with distinct order counts and share', () => {
    const rows = aggregateProductSales(items);
    expect(rows[0]).toMatchObject({
      productName: 'Set of 5 Macarons',
      unitsSold: 2,
      orders: 1,
      revenue: 380000,
    });
    const lemon = rows.find((r) => r.variantLabel === 'Single · Lemon')!;
    expect(lemon).toMatchObject({ unitsSold: 3, orders: 2, revenue: 114000, sku: 'VT00083' });
    expect(rows.reduce((s, r) => s + r.share, 0)).toBeCloseTo(100, 0);
  });

  it('expands composed-set flavours by line quantity', () => {
    expect(aggregateFlavors(items)).toEqual([
      { productName: 'Set of 5 Macarons', flavor: 'Jasmine', units: 6 },
      { productName: 'Set of 5 Macarons', flavor: 'Lemon', units: 4 },
    ]);
  });

  it('describes personalization compactly', () => {
    expect(describePersonalization({ flavors: { Jasmine: 3, Lemon: 2 } })).toBe(
      'Jasmine×3, Lemon×2',
    );
    expect(
      describePersonalization({
        textOnCake: 'Happy birthday',
        candleType: 'number',
        candleNumber: 30,
        note: null,
      }),
    ).toBe('Nến số 30 · Chữ trên bánh: Happy birthday');
    expect(describePersonalization({ candleType: 'regular', candleCount: 5 })).toBe(
      'Nến thường ×5',
    );
    expect(describePersonalization(null)).toBe('');
  });

  it('uses ICT calendar days and hours', () => {
    const d = new Date('2026-09-09T20:30:00Z'); // 03:30 ICT next day
    expect(ictDay(d)).toBe('2026-09-10');
    expect(ictHour(d)).toBe(3);
  });
});

import { renderTransferSheetPdf, transferDayLabel } from './transfer-sheet-pdf';

describe('transferDayLabel', () => {
  it('names the Vietnamese weekday', () => {
    expect(transferDayLabel('2026-09-05')).toBe('Thứ 7 05/09/2026');
    expect(transferDayLabel('2026-09-06')).toBe('Chủ nhật 06/09/2026');
  });
});

describe('renderTransferSheetPdf', () => {
  it('renders a landscape sheet with four branches, sections and a shortfall', async () => {
    const stores = ['s1', 's2', 's3', 's4'].map((id, i) => ({
      id,
      name: `Banan – Chi nhánh ${i + 1}`,
    }));
    const rows = Array.from({ length: 45 }, (_, i) => ({
      key: `i:Bánh ${i}`,
      label: `Bánh số ${i} với tên khá dài để thử cột`,
      unit: 'cái',
      isSupply: i >= 40,
      isDrinkIngredient: i >= 40 && i < 43,
      byStore: Object.fromEntries(
        stores.map((s, k) => [
          s.id,
          { ordered: 5 + k, shipped: i % 7 === 0 ? 4 + k : 5 + k, lines: [] },
        ]),
      ),
      ordered: 5 + 6 + 7 + 8,
      shipped: i % 7 === 0 ? 5 + 6 + 7 + 8 - 4 : 5 + 6 + 7 + 8,
    }));
    const bytes = await renderTransferSheetPdf({
      day: '2026-09-05',
      orders: [{ id: 'o1', code: 'BAN-2026-A', storeId: 's1', kitchenStatus: null }],
      stores,
      rows,
    });
    expect(bytes.subarray(0, 5).toString()).toBe('%PDF-');
    // 45 rows at 18pt do not fit one landscape page: the header repeats.
    expect(bytes.toString('latin1').match(/\/Type\s*\/Page[^s]/g)?.length).toBeGreaterThan(1);
  });
});

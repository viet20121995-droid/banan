import type { DeliveryConfig } from '@prisma/client';

import { DeliveryConfigService } from './delivery-config.service';

const cfg = {
  standardFeeSameWardVnd: 0,
  standardFeeOtherWardVnd: 30_000,
  birthdayCakeFeeSameWardVnd: 30_000,
  birthdayCakeFeeOtherWardVnd: 70_000,
} as DeliveryConfig;
const svc = new DeliveryConfigService({} as never);
const fee = (km: number | null, cake: boolean, subtotal = 300_000) =>
  svc.feeFor(cfg, 'phu-tho', 'hoa-hung', cake, km, subtotal);

describe('delivery fee (02/10/2026 rules)', () => {
  it('keeps the ward rates within ~5 km by road', () => {
    expect(fee(3.8, false)).toBe(30_000); // 4.94 km road
    expect(fee(3.8, true)).toBe(70_000);
    expect(fee(null, false)).toBe(30_000);
  });
  it('charges the far rate past 5 km by road (straight × 1.3)', () => {
    expect(fee(3.9, false)).toBe(50_000); // 5.07 km road
    expect(fee(5.9, true)).toBe(100_000);
  });
  it('ships free from 1,000,000 ₫ whatever the distance', () => {
    expect(fee(5.9, true, 1_000_000)).toBe(0);
    expect(fee(1, false, 999_999)).toBe(30_000);
  });
});

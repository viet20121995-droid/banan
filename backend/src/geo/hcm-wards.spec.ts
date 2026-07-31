import {
  AMBIGUOUS_LEGACY_WARDS,
  canonicalWardCode,
  findWard,
  FORMER_HCMC_WARD_CODES,
  FORMER_HCMC_WARDS,
  haversineKm,
  HCM_WARDS,
  isAmbiguousLegacyWard,
  isFormerHcmcWard,
  isWardServiceable,
  LEGACY_WARD_ALIASES,
} from './hcm-wards';

describe('HCM ward catalog (NQ 1685/NQ-UBTVQH15)', () => {
  it('contains exactly 168 units: 113 phường, 54 xã, 1 đặc khu', () => {
    expect(HCM_WARDS).toHaveLength(168);
    const byType = HCM_WARDS.reduce<Record<string, number>>((acc, w) => {
      acc[w.type] = (acc[w.type] ?? 0) + 1;
      return acc;
    }, {});
    expect(byType).toEqual({ phuong: 113, xa: 54, 'dac-khu': 1 });
  });

  it('limits the customer delivery catalog to the 102 former-HCMC units', () => {
    expect(FORMER_HCMC_WARD_CODES.size).toBe(102);
    expect(FORMER_HCMC_WARDS).toHaveLength(102);
    expect(FORMER_HCMC_WARDS.every((ward) => isFormerHcmcWard(ward))).toBe(true);

    for (const code of ['sai-gon', 'an-phu-dong', 'thu-duc', 'can-gio', 'hiep-phuoc']) {
      expect(isFormerHcmcWard(code)).toBe(true);
    }

    for (const code of ['an-phu-thuan-an', 'thu-dau-mot', 'vung-tau', 'phu-my-ba-ria', 'con-dao']) {
      expect(isFormerHcmcWard(code)).toBe(false);
      expect(FORMER_HCMC_WARDS.some((ward) => ward.code === code)).toBe(false);
    }
  });

  it('has no empty or duplicate codes and no empty names', () => {
    const codes = new Set<string>();
    for (const w of HCM_WARDS) {
      expect(w.code).toMatch(/^[a-z0-9-]+$/);
      expect(w.name.trim()).not.toBe('');
      expect(codes.has(w.code)).toBe(false);
      codes.add(w.code);
    }
  });

  it('prefixes every name with its unit type', () => {
    for (const w of HCM_WARDS) {
      const prefix = w.type === 'phuong' ? 'Phường ' : w.type === 'xa' ? 'Xã ' : 'Đặc khu ';
      expect(w.name.startsWith(prefix)).toBe(true);
    }
  });

  it('findWard resolves every canonical code', () => {
    for (const w of HCM_WARDS) {
      expect(findWard(w.code)).toBe(w);
    }
  });

  it('resolves every SAFE legacy alias to an existing canonical ward', () => {
    for (const [legacy, canonical] of Object.entries(LEGACY_WARD_ALIASES)) {
      // Alias codes must not shadow a canonical code.
      expect(HCM_WARDS.some((w) => w.code === legacy)).toBe(false);
      const resolved = findWard(legacy);
      expect(resolved).not.toBeNull();
      expect(resolved!.code).toBe(canonical);
      expect(canonicalWardCode(legacy)).toBe(canonical);
      expect(isAmbiguousLegacyWard(legacy)).toBe(false);
    }
  });

  it('never auto-maps a SPLIT pre-reform ward — reselection required', () => {
    expect(Object.keys(AMBIGUOUS_LEGACY_WARDS).sort()).toEqual(['an-phu', 'da-kao', 'phu-my']);
    for (const [legacy, candidates] of Object.entries(AMBIGUOUS_LEGACY_WARDS)) {
      // Not a canonical code, not a safe alias, and never guessed.
      expect(HCM_WARDS.some((w) => w.code === legacy)).toBe(false);
      expect(isAmbiguousLegacyWard(legacy)).toBe(true);
      expect(canonicalWardCode(legacy)).toBeNull();
      expect(findWard(legacy)).toBeNull();
      // Every candidate the support tooling offers must exist.
      expect(candidates.length).toBeGreaterThanOrEqual(2);
      for (const c of candidates) {
        expect(findWard(c)).not.toBeNull();
      }
    }
  });

  it('keeps the wardCodes already stored on prod addresses/stores resolvable', () => {
    // Seeded store wards + whole-merge legacy codes: must keep routing.
    const resolvable = [
      'sai-gon',
      'hoa-hung',
      'an-khanh',
      'cau-kieu',
      'cau-kho',
      'thao-dien',
      'dieu-chi-thang',
    ];
    for (const code of resolvable) {
      const ward = findWard(code);
      expect(ward).not.toBeNull();
      // These are all inner-city areas — they must stay deliverable.
      expect(isWardServiceable(ward)).toBe(true);
    }
    // Split-ward codes stay recognized (≠ WARD_NOT_FOUND) but demand a
    // fresh customer pick instead of a guessed mapping.
    for (const code of ['da-kao', 'an-phu', 'phu-my']) {
      expect(isAmbiguousLegacyWard(code)).toBe(true);
      expect(findWard(code)).toBeNull();
    }
  });

  it('contains all 5 wards formed from old Quận 12', () => {
    const q12 = HCM_WARDS.filter((w) => (w.oldArea ?? '').includes('Quận 12'));
    expect(q12.map((w) => w.code).sort()).toEqual([
      'an-phu-dong',
      'dong-hung-thuan',
      'tan-thoi-hiep',
      'thoi-an',
      'trung-my-tay',
    ]);
    // Searchable via a constituent old ward name too.
    expect(q12.some((w) => (w.oldArea ?? '').includes('Thạnh Lộc'))).toBe(true);
  });

  it('keeps name collisions across merged provinces on distinct codes', () => {
    // Phường An Phú (Thuận An, Bình Dương) must NOT reuse the legacy Thủ Đức
    // `an-phu` code; same for Phường Phú Mỹ (Bà Rịa - Vũng Tàu) vs old Q7.
    // The legacy codes themselves are split-ward codes → reselection.
    expect(findWard('an-phu-thuan-an')!.name).toBe('Phường An Phú');
    expect(isAmbiguousLegacyWard('an-phu')).toBe(true);
    expect(findWard('phu-my-ba-ria')!.name).toBe('Phường Phú Mỹ');
    expect(isAmbiguousLegacyWard('phu-my')).toBe(true);
    // Xã Thanh An (Dầu Tiếng) vs Xã Thạnh An (Cần Giờ) — identical slugs
    // once diacritics are stripped; both must exist under suffixed codes.
    expect(findWard('thanh-an-dau-tieng')!.name).toBe('Xã Thanh An');
    expect(findWard('thanh-an-can-gio')!.name).toBe('Xã Thạnh An');
  });

  it('marks wards without a centroid as valid but not serviceable', () => {
    const conDao = findWard('con-dao')!;
    expect(conDao.type).toBe('dac-khu');
    expect(isWardServiceable(conDao)).toBe(false);
    // Not-found is different from not-serviceable.
    expect(findWard('khong-ton-tai')).toBeNull();
    expect(isWardServiceable(findWard('khong-ton-tai'))).toBe(false);
  });

  it('every serviceable centroid is a sane HCMC-region coordinate', () => {
    for (const w of HCM_WARDS) {
      const hasLat = w.lat != null;
      const hasLng = w.lng != null;
      // Coordinates come in pairs — never one half of a point.
      expect(hasLat).toBe(hasLng);
      // Delivery POLICY and geo stay consistent: an approved ward must be
      // routable, and (today) every ward with a verified centroid is in
      // the approved zone. Adding coordinates alone must never open
      // delivery — that requires the explicit inDeliveryZone flag.
      if (w.inDeliveryZone === true) {
        expect(hasLat).toBe(true);
        expect(isWardServiceable(w)).toBe(true);
      } else {
        expect(isWardServiceable(w)).toBe(false);
      }
      if (w.lat != null && w.lng != null) {
        expect(Number.isFinite(w.lat)).toBe(true);
        expect(Number.isFinite(w.lng)).toBe(true);
        expect(w.lat).toBeGreaterThan(10.3);
        expect(w.lat).toBeLessThan(11.5);
        expect(w.lng).toBeGreaterThan(106.3);
        expect(w.lng).toBeLessThan(107.7);
      }
    }
  });

  it('haversine never yields NaN for serviceable ward pairs', () => {
    const serviceable = HCM_WARDS.filter((w) => isWardServiceable(w));
    expect(serviceable.length).toBeGreaterThan(0);
    const origin = { lat: serviceable[0]!.lat!, lng: serviceable[0]!.lng! };
    for (const w of serviceable) {
      const km = haversineKm(origin, { lat: w.lat!, lng: w.lng! });
      expect(Number.isFinite(km)).toBe(true);
      expect(km).toBeGreaterThanOrEqual(0);
      expect(km).toBeLessThan(150);
    }
  });
});

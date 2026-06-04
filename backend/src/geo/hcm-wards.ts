/**
 * HCMC ward catalog after the July 2025 administrative reform.
 *
 * Before the reform: 22 quận/huyện × ~310 phường/xã. After: districts are
 * abolished — phường/xã sit directly under the city, total ~168 units.
 *
 * This catalog is a curated subset covering the inner-city wards where the
 * Banan branches operate. Each entry carries an approximate centroid
 * (lat/lng) used by `OrdersService` to compute the haversine distance from
 * the fulfilling store. Distances >3km trigger a surcharge on top of the
 * flat delivery fee.
 *
 * The `code` is a stable slug-style id — it's stored on the address row and
 * shipped over the wire to the frontend. The `name` (and optional `oldArea`
 * hint with the pre-reform district) is for human-readable display.
 */
export interface HcmWard {
  /** Slug-style stable id. Stored on Address.wardCode. */
  code: string;
  /** Display name including "Phường" / "Xã" prefix. */
  name: string;
  /** Approximate centroid latitude (WGS84). */
  lat: number;
  /** Approximate centroid longitude (WGS84). */
  lng: number;
  /** Pre-reform district hint — helps customers find the right ward. */
  oldArea?: string;
}

export const HCM_WARDS: HcmWard[] = [
  // ── Central core (old District 1 / 3 / 4) ────────────────────────────
  { code: 'sai-gon',        name: 'Phường Sài Gòn',        lat: 10.7770, lng: 106.7019, oldArea: 'Bến Nghé · Q1' },
  { code: 'ben-thanh',      name: 'Phường Bến Thành',      lat: 10.7720, lng: 106.6986, oldArea: 'Bến Thành · Q1' },
  { code: 'tan-dinh',       name: 'Phường Tân Định',       lat: 10.7902, lng: 106.6907, oldArea: 'Tân Định · Q1/Q3' },
  { code: 'cau-ong-lanh',   name: 'Phường Cầu Ông Lãnh',   lat: 10.7679, lng: 106.6925, oldArea: 'Cầu Ông Lãnh · Q1' },
  { code: 'cau-kho',        name: 'Phường Cầu Kho',        lat: 10.7593, lng: 106.6905, oldArea: 'Cầu Kho · Q1' },
  { code: 'da-kao',         name: 'Phường Đa Kao',         lat: 10.7886, lng: 106.6989, oldArea: 'Đa Kao · Q1' },
  { code: 'ban-co',         name: 'Phường Bàn Cờ',         lat: 10.7726, lng: 106.6817, oldArea: 'Bàn Cờ · Q3' },
  { code: 'xuan-hoa',       name: 'Phường Xuân Hòa',       lat: 10.7800, lng: 106.6810, oldArea: 'Q3' },
  { code: 'vuon-lai',       name: 'Phường Vườn Lài',       lat: 10.7855, lng: 106.6760, oldArea: 'Q3' },
  { code: 'nhieu-loc',      name: 'Phường Nhiêu Lộc',      lat: 10.7950, lng: 106.6700, oldArea: 'Q3' },
  { code: 'vinh-hoi',       name: 'Phường Vĩnh Hội',       lat: 10.7530, lng: 106.6970, oldArea: 'Q4' },
  { code: 'khanh-hoi',      name: 'Phường Khánh Hội',      lat: 10.7620, lng: 106.7020, oldArea: 'Q4' },
  { code: 'xom-chieu',      name: 'Phường Xóm Chiếu',      lat: 10.7660, lng: 106.7040, oldArea: 'Q4' },

  // ── Bình Thạnh / Phú Nhuận ──────────────────────────────────────────
  { code: 'binh-thanh',     name: 'Phường Bình Thạnh',     lat: 10.8000, lng: 106.7100, oldArea: 'Bình Thạnh' },
  { code: 'gia-dinh',       name: 'Phường Gia Định',       lat: 10.8042, lng: 106.6920, oldArea: 'Bình Thạnh' },
  { code: 'binh-loi-trung', name: 'Phường Bình Lợi Trung', lat: 10.8120, lng: 106.7090, oldArea: 'Bình Thạnh' },
  { code: 'phu-nhuan',      name: 'Phường Phú Nhuận',      lat: 10.7969, lng: 106.6800, oldArea: 'Phú Nhuận' },
  { code: 'duc-nhuan',      name: 'Phường Đức Nhuận',      lat: 10.7980, lng: 106.6700, oldArea: 'Phú Nhuận' },
  { code: 'cau-kieu',       name: 'Phường Cầu Kiệu',       lat: 10.7900, lng: 106.6840, oldArea: 'Phú Nhuận' },

  // ── Tân Bình ────────────────────────────────────────────────────────
  { code: 'tan-hoa',        name: 'Phường Tân Hòa',        lat: 10.7800, lng: 106.6600, oldArea: 'Tân Bình' },
  { code: 'tan-son-hoa',    name: 'Phường Tân Sơn Hòa',    lat: 10.7950, lng: 106.6660, oldArea: 'Tân Bình' },
  { code: 'tan-son-nhat',   name: 'Phường Tân Sơn Nhất',   lat: 10.8020, lng: 106.6660, oldArea: 'Tân Bình' },
  { code: 'bay-hien',       name: 'Phường Bảy Hiền',       lat: 10.7920, lng: 106.6540, oldArea: 'Tân Bình' },

  // ── Old D5 / D6 / D8 (Chợ Lớn area) ─────────────────────────────────
  { code: 'cho-quan',       name: 'Phường Chợ Quán',       lat: 10.7530, lng: 106.6843, oldArea: 'Q5' },
  { code: 'an-dong',        name: 'Phường An Đông',        lat: 10.7565, lng: 106.6770, oldArea: 'Q5' },
  { code: 'cho-lon',        name: 'Phường Chợ Lớn',        lat: 10.7507, lng: 106.6630, oldArea: 'Q5/Q6' },
  { code: 'binh-tien',      name: 'Phường Bình Tiên',      lat: 10.7448, lng: 106.6577, oldArea: 'Q6' },
  { code: 'phu-lam',        name: 'Phường Phú Lâm',        lat: 10.7430, lng: 106.6440, oldArea: 'Q6' },
  { code: 'binh-phu',       name: 'Phường Bình Phú',       lat: 10.7430, lng: 106.6360, oldArea: 'Q6' },

  // ── Thủ Đức (east) ──────────────────────────────────────────────────
  { code: 'thu-duc',        name: 'Phường Thủ Đức',        lat: 10.8500, lng: 106.7700, oldArea: 'Thủ Đức' },
  { code: 'thao-dien',      name: 'Phường Thảo Điền',      lat: 10.8060, lng: 106.7370, oldArea: 'Thủ Đức' },
  { code: 'an-phu',         name: 'Phường An Phú',         lat: 10.7950, lng: 106.7480, oldArea: 'Thủ Đức' },
  { code: 'an-khanh',       name: 'Phường An Khánh',       lat: 10.7800, lng: 106.7330, oldArea: 'Thủ Đức' },
  { code: 'binh-trung',     name: 'Phường Bình Trưng',     lat: 10.7850, lng: 106.7670, oldArea: 'Thủ Đức' },

  // ── Old D7 / Nhà Bè (south) ─────────────────────────────────────────
  { code: 'tan-thuan',      name: 'Phường Tân Thuận',      lat: 10.7380, lng: 106.7240, oldArea: 'Q7' },
  { code: 'tan-my',         name: 'Phường Tân Mỹ',         lat: 10.7260, lng: 106.7140, oldArea: 'Q7' },
  { code: 'phu-my',         name: 'Phường Phú Mỹ',         lat: 10.7150, lng: 106.7290, oldArea: 'Q7' },

  // ── Old D10 / D11 ───────────────────────────────────────────────────
  { code: 'hoa-hung',       name: 'Phường Hòa Hưng',       lat: 10.7800, lng: 106.6700, oldArea: 'Q10' },
  { code: 'dieu-chi-thang', name: 'Phường Diên Hồng',      lat: 10.7710, lng: 106.6680, oldArea: 'Q10' },
  { code: 'minh-phung',     name: 'Phường Minh Phụng',     lat: 10.7620, lng: 106.6480, oldArea: 'Q11' },
];

const byCode = new Map(HCM_WARDS.map((w) => [w.code, w]));

export function findWard(code: string | null | undefined): HcmWard | null {
  if (!code) return null;
  return byCode.get(code) ?? null;
}

/**
 * Great-circle distance in kilometres between two WGS84 points. Standard
 * haversine — accurate to ~0.5% within a metropolitan area, more than
 * enough for a 3 km surcharge threshold.
 */
export function haversineKm(
  a: { lat: number; lng: number },
  b: { lat: number; lng: number },
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const R = 6371; // Earth radius (km)
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.sin(dLng / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);
  return 2 * R * Math.asin(Math.sqrt(x));
}

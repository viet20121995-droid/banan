/**
 * Full catalog of Ho Chi Minh City's 168 cấp-xã administrative units in
 * force since 01/07/2025 — 113 phường + 54 xã + 1 đặc khu (Côn Đảo) —
 * per Nghị quyết 1685/NQ-UBTVQH15 (sắp xếp TP.HCM + Bình Dương +
 * Bà Rịa - Vũng Tàu). Names and composition follow the official list
 * republished by the Government:
 * https://xaydungchinhsach.chinhphu.vn/sap-xep-dvhc-danh-sach-168-xa-phuong-dac-khu-cua-thanh-pho-ho-chi-minh-119250623085031865.htm
 *
 * The `code` is a stable slug-style id — stored on Address.wardCode and
 * Store.wardCode and shipped over the wire. Codes that existed in the old
 * curated catalog are preserved verbatim; wards that no longer exist after
 * the reform live on as LEGACY_WARD_ALIASES so saved addresses keep
 * resolving. Name collisions across the merged provinces get an old-area
 * suffix (e.g. `an-phu-thuan-an`) so every code stays unique.
 *
 * `lat`/`lng` is the approximate centroid used ONLY to route delivery to
 * the nearest branch and to display the distance. Coordinates are kept for
 * the wards Banan currently serves (carried over from the shipped catalog).
 * Wards without verified coordinates carry `null` — they are VALID picks
 * (address book, pickup orders) but delivery to them is not supported yet;
 * admin supplies centroids when the delivery zone expands. Never invent
 * coordinates here.
 */
export interface HcmWard {
  /** Slug-style stable id. Stored on Address.wardCode / Store.wardCode. */
  code: string;
  /** Display name including the "Phường" / "Xã" / "Đặc khu" prefix. */
  name: string;
  /** Unit kind — drives catalog integrity checks and counts. */
  type: 'phuong' | 'xa' | 'dac-khu';
  /** Approximate centroid latitude (WGS84), null = no verified centroid. */
  lat: number | null;
  /** Approximate centroid longitude (WGS84), null = no verified centroid. */
  lng: number | null;
  /**
   * Delivery POLICY flag — true only for wards the merchant has approved
   * for delivery. Deliberately separate from the centroid: adding
   * coordinates alone must never silently open a ward for delivery, and
   * the zone can shrink without deleting geo data.
   */
  inDeliveryZone?: boolean;
  /** Pre-reform source wards / district hint — display + search. */
  oldArea?: string;
}

const P = 'phuong' as const;
const X = 'xa' as const;

export const HCM_WARDS: HcmWard[] = [
  // ── TP.HCM cũ — Quận 1 ──────────────────────────────────────────────
  {
    code: 'sai-gon',
    name: 'Phường Sài Gòn',
    type: P,
    inDeliveryZone: true,
    lat: 10.777,
    lng: 106.7019,
    oldArea: 'Bến Nghé, Đa Kao, Nguyễn Thái Bình · Q1',
  },
  {
    code: 'tan-dinh',
    name: 'Phường Tân Định',
    type: P,
    inDeliveryZone: true,
    lat: 10.7902,
    lng: 106.6907,
    oldArea: 'Tân Định, Đa Kao · Q1',
  },
  {
    code: 'ben-thanh',
    name: 'Phường Bến Thành',
    type: P,
    inDeliveryZone: true,
    lat: 10.772,
    lng: 106.6986,
    oldArea: 'Bến Thành, Phạm Ngũ Lão, Nguyễn Thái Bình · Q1',
  },
  {
    code: 'cau-ong-lanh',
    name: 'Phường Cầu Ông Lãnh',
    type: P,
    inDeliveryZone: true,
    lat: 10.7679,
    lng: 106.6925,
    oldArea: 'Nguyễn Cư Trinh, Cầu Kho, Cô Giang · Q1',
  },
  // ── Quận 3 ──────────────────────────────────────────────────────────
  {
    code: 'ban-co',
    name: 'Phường Bàn Cờ',
    type: P,
    inDeliveryZone: true,
    lat: 10.7726,
    lng: 106.6817,
    oldArea: 'P.1, 2, 3, 5 · Q3',
  },
  {
    code: 'xuan-hoa',
    name: 'Phường Xuân Hòa',
    type: P,
    inDeliveryZone: true,
    lat: 10.78,
    lng: 106.681,
    oldArea: 'Võ Thị Sáu, P.4 · Q3',
  },
  {
    code: 'nhieu-loc',
    name: 'Phường Nhiêu Lộc',
    type: P,
    inDeliveryZone: true,
    lat: 10.795,
    lng: 106.67,
    oldArea: 'P.9, 11, 12, 14 · Q3',
  },
  // ── Quận 4 ──────────────────────────────────────────────────────────
  {
    code: 'xom-chieu',
    name: 'Phường Xóm Chiếu',
    type: P,
    inDeliveryZone: true,
    lat: 10.766,
    lng: 106.704,
    oldArea: 'P.13, 15, 16, 18 · Q4',
  },
  {
    code: 'khanh-hoi',
    name: 'Phường Khánh Hội',
    type: P,
    inDeliveryZone: true,
    lat: 10.762,
    lng: 106.702,
    oldArea: 'P.2, 4, 5, 8, 9 · Q4',
  },
  {
    code: 'vinh-hoi',
    name: 'Phường Vĩnh Hội',
    type: P,
    inDeliveryZone: true,
    lat: 10.753,
    lng: 106.697,
    oldArea: 'P.1, 2, 3, 4 · Q4',
  },
  // ── Quận 5 ──────────────────────────────────────────────────────────
  {
    code: 'cho-quan',
    name: 'Phường Chợ Quán',
    type: P,
    inDeliveryZone: true,
    lat: 10.753,
    lng: 106.6843,
    oldArea: 'P.1, 2, 4 · Q5',
  },
  {
    code: 'an-dong',
    name: 'Phường An Đông',
    type: P,
    inDeliveryZone: true,
    lat: 10.7565,
    lng: 106.677,
    oldArea: 'P.5, 7, 9 · Q5',
  },
  {
    code: 'cho-lon',
    name: 'Phường Chợ Lớn',
    type: P,
    inDeliveryZone: true,
    lat: 10.7507,
    lng: 106.663,
    oldArea: 'P.11, 12, 13, 14 · Q5',
  },
  // ── Quận 6 ──────────────────────────────────────────────────────────
  {
    code: 'binh-tay',
    name: 'Phường Bình Tây',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.2, 9 · Q6',
  },
  {
    code: 'binh-tien',
    name: 'Phường Bình Tiên',
    type: P,
    inDeliveryZone: true,
    lat: 10.7448,
    lng: 106.6577,
    oldArea: 'P.1, 7, 8 · Q6',
  },
  {
    code: 'binh-phu',
    name: 'Phường Bình Phú',
    type: P,
    inDeliveryZone: true,
    lat: 10.743,
    lng: 106.636,
    oldArea: 'P.10, 11 · Q6',
  },
  {
    code: 'phu-lam',
    name: 'Phường Phú Lâm',
    type: P,
    inDeliveryZone: true,
    lat: 10.743,
    lng: 106.644,
    oldArea: 'P.12, 13, 14 · Q6',
  },
  // ── Quận 7 ──────────────────────────────────────────────────────────
  {
    code: 'tan-thuan',
    name: 'Phường Tân Thuận',
    type: P,
    inDeliveryZone: true,
    lat: 10.738,
    lng: 106.724,
    oldArea: 'Bình Thuận, Tân Thuận Đông, Tân Thuận Tây · Q7',
  },
  {
    code: 'phu-thuan',
    name: 'Phường Phú Thuận',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Phú Thuận, Phú Mỹ · Q7',
  },
  {
    code: 'tan-my',
    name: 'Phường Tân Mỹ',
    type: P,
    inDeliveryZone: true,
    lat: 10.726,
    lng: 106.714,
    oldArea: 'Tân Phú, Phú Mỹ · Q7',
  },
  {
    code: 'tan-hung',
    name: 'Phường Tân Hưng',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Tân Phong, Tân Quy, Tân Kiểng, Tân Hưng · Q7',
  },
  // ── Quận 8 ──────────────────────────────────────────────────────────
  {
    code: 'chanh-hung',
    name: 'Phường Chánh Hưng',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.4, 5, Rạch Ông, Hưng Phú · Q8',
  },
  {
    code: 'phu-dinh',
    name: 'Phường Phú Định',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.14, 15, 16, Xóm Củi · Q8',
  },
  {
    code: 'binh-dong',
    name: 'Phường Bình Đông',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.5, 6, 7 · Q8',
  },
  // ── Quận 10 ─────────────────────────────────────────────────────────
  {
    code: 'dien-hong',
    name: 'Phường Diên Hồng',
    type: P,
    inDeliveryZone: true,
    lat: 10.771,
    lng: 106.668,
    oldArea: 'P.6, 8, 14 · Q10',
  },
  {
    code: 'vuon-lai',
    name: 'Phường Vườn Lài',
    type: P,
    inDeliveryZone: true,
    lat: 10.7855,
    lng: 106.676,
    oldArea: 'P.1, 2, 4, 9, 10 · Q10',
  },
  {
    code: 'hoa-hung',
    name: 'Phường Hòa Hưng',
    type: P,
    inDeliveryZone: true,
    lat: 10.78,
    lng: 106.67,
    oldArea: 'P.12, 13, 14, 15 · Q10',
  },
  // ── Quận 11 ─────────────────────────────────────────────────────────
  {
    code: 'minh-phung',
    name: 'Phường Minh Phụng',
    type: P,
    inDeliveryZone: true,
    lat: 10.762,
    lng: 106.648,
    oldArea: 'P.1, 7, 16 · Q11',
  },
  {
    code: 'binh-thoi',
    name: 'Phường Bình Thới',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.3, 8, 10 · Q11',
  },
  {
    code: 'hoa-binh',
    name: 'Phường Hòa Bình',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.5, 14 · Q11',
  },
  {
    code: 'phu-tho',
    name: 'Phường Phú Thọ',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.8, 11, 15 · Q11',
  },
  // ── Quận 12 ─────────────────────────────────────────────────────────
  {
    code: 'dong-hung-thuan',
    name: 'Phường Đông Hưng Thuận',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Tân Thới Nhất, Tân Hưng Thuận, Đông Hưng Thuận · Quận 12',
  },
  {
    code: 'trung-my-tay',
    name: 'Phường Trung Mỹ Tây',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Tân Chánh Hiệp, Trung Mỹ Tây · Quận 12',
  },
  {
    code: 'tan-thoi-hiep',
    name: 'Phường Tân Thới Hiệp',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Hiệp Thành, Tân Thới Hiệp · Quận 12',
  },
  {
    code: 'thoi-an',
    name: 'Phường Thới An',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Thạnh Xuân, Thới An · Quận 12',
  },
  {
    code: 'an-phu-dong',
    name: 'Phường An Phú Đông',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Thạnh Lộc, An Phú Đông · Quận 12',
  },
  // ── Bình Tân ────────────────────────────────────────────────────────
  {
    code: 'an-lac',
    name: 'Phường An Lạc',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'An Lạc, An Lạc A, Bình Trị Đông B · Bình Tân',
  },
  {
    code: 'binh-tan',
    name: 'Phường Bình Tân',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Bình Hưng Hòa B, Bình Trị Đông A, Tân Tạo · Bình Tân',
  },
  {
    code: 'tan-tao',
    name: 'Phường Tân Tạo',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Tân Tạo, Tân Tạo A, Tân Kiên · Bình Tân',
  },
  {
    code: 'binh-tri-dong',
    name: 'Phường Bình Trị Đông',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Bình Trị Đông, Bình Hưng Hòa A · Bình Tân',
  },
  {
    code: 'binh-hung-hoa',
    name: 'Phường Bình Hưng Hòa',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Bình Hưng Hòa, Sơn Kỳ · Bình Tân',
  },
  // ── Bình Thạnh ──────────────────────────────────────────────────────
  {
    code: 'gia-dinh',
    name: 'Phường Gia Định',
    type: P,
    inDeliveryZone: true,
    lat: 10.8042,
    lng: 106.692,
    oldArea: 'P.1, 2, 7, 17 · Bình Thạnh',
  },
  {
    code: 'binh-thanh',
    name: 'Phường Bình Thạnh',
    type: P,
    inDeliveryZone: true,
    lat: 10.8,
    lng: 106.71,
    oldArea: 'P.12, 14, 26 · Bình Thạnh',
  },
  {
    code: 'binh-loi-trung',
    name: 'Phường Bình Lợi Trung',
    type: P,
    inDeliveryZone: true,
    lat: 10.812,
    lng: 106.709,
    oldArea: 'P.5, 11, 13 · Bình Thạnh',
  },
  {
    code: 'thanh-my-tay',
    name: 'Phường Thạnh Mỹ Tây',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.19, 22, 25 · Bình Thạnh',
  },
  {
    code: 'binh-quoi',
    name: 'Phường Bình Quới',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.27, 28 · Bình Thạnh',
  },
  // ── Gò Vấp ──────────────────────────────────────────────────────────
  {
    code: 'hanh-thong',
    name: 'Phường Hạnh Thông',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.1, 3 · Gò Vấp',
  },
  {
    code: 'an-nhon',
    name: 'Phường An Nhơn',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.5, 6 · Gò Vấp',
  },
  {
    code: 'go-vap',
    name: 'Phường Gò Vấp',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.10, 17 · Gò Vấp',
  },
  {
    code: 'an-hoi-dong',
    name: 'Phường An Hội Đông',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.15, 16 · Gò Vấp',
  },
  {
    code: 'thong-tay-hoi',
    name: 'Phường Thông Tây Hội',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.8, 11 · Gò Vấp',
  },
  {
    code: 'an-hoi-tay',
    name: 'Phường An Hội Tây',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.12, 14 · Gò Vấp',
  },
  // ── Phú Nhuận ───────────────────────────────────────────────────────
  {
    code: 'duc-nhuan',
    name: 'Phường Đức Nhuận',
    type: P,
    inDeliveryZone: true,
    lat: 10.798,
    lng: 106.67,
    oldArea: 'P.4, 5, 9 · Phú Nhuận',
  },
  {
    code: 'cau-kieu',
    name: 'Phường Cầu Kiệu',
    type: P,
    inDeliveryZone: true,
    lat: 10.79,
    lng: 106.684,
    oldArea: 'P.1, 2, 7, 15 · Phú Nhuận',
  },
  {
    code: 'phu-nhuan',
    name: 'Phường Phú Nhuận',
    type: P,
    inDeliveryZone: true,
    lat: 10.7969,
    lng: 106.68,
    oldArea: 'P.8, 10, 11, 13 · Phú Nhuận',
  },
  // ── Tân Bình ────────────────────────────────────────────────────────
  {
    code: 'tan-son-hoa',
    name: 'Phường Tân Sơn Hòa',
    type: P,
    inDeliveryZone: true,
    lat: 10.795,
    lng: 106.666,
    oldArea: 'P.1, 2, 3 · Tân Bình',
  },
  {
    code: 'tan-son-nhat',
    name: 'Phường Tân Sơn Nhất',
    type: P,
    inDeliveryZone: true,
    lat: 10.802,
    lng: 106.666,
    oldArea: 'P.4, 5, 7 · Tân Bình',
  },
  {
    code: 'tan-hoa',
    name: 'Phường Tân Hòa',
    type: P,
    inDeliveryZone: true,
    lat: 10.78,
    lng: 106.66,
    oldArea: 'P.6, 8, 9 · Tân Bình',
  },
  {
    code: 'bay-hien',
    name: 'Phường Bảy Hiền',
    type: P,
    inDeliveryZone: true,
    lat: 10.792,
    lng: 106.654,
    oldArea: 'P.10, 11, 12 · Tân Bình',
  },
  {
    code: 'tan-binh',
    name: 'Phường Tân Bình',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.13, 14, 15 · Tân Bình',
  },
  {
    code: 'tan-son',
    name: 'Phường Tân Sơn',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.15 · Tân Bình',
  },
  // ── Tân Phú ─────────────────────────────────────────────────────────
  {
    code: 'tay-thanh',
    name: 'Phường Tây Thạnh',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Tây Thạnh, Sơn Kỳ · Tân Phú',
  },
  {
    code: 'tan-son-nhi',
    name: 'Phường Tân Sơn Nhì',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Tân Sơn Nhì, Tân Quý, Tân Thành · Tân Phú',
  },
  {
    code: 'phu-tho-hoa',
    name: 'Phường Phú Thọ Hòa',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Phú Thọ Hòa, Tân Quý, Tân Thành · Tân Phú',
  },
  {
    code: 'tan-phu',
    name: 'Phường Tân Phú',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Phú Trung, Hòa Thạnh, Tân Thới Hòa · Tân Phú',
  },
  {
    code: 'phu-thanh',
    name: 'Phường Phú Thạnh',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Hiệp Tân, Phú Thạnh, Tân Thới Hòa · Tân Phú',
  },
  // ── Thủ Đức ─────────────────────────────────────────────────────────
  {
    code: 'hiep-binh',
    name: 'Phường Hiệp Bình',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Hiệp Bình Chánh, Hiệp Bình Phước, Linh Đông · Thủ Đức',
  },
  {
    code: 'thu-duc',
    name: 'Phường Thủ Đức',
    type: P,
    inDeliveryZone: true,
    lat: 10.85,
    lng: 106.77,
    oldArea: 'Bình Thọ, Linh Chiểu, Trường Thọ, Linh Tây · Thủ Đức',
  },
  {
    code: 'tam-binh',
    name: 'Phường Tam Bình',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Bình Chiểu, Tam Phú, Tam Bình · Thủ Đức',
  },
  {
    code: 'linh-xuan',
    name: 'Phường Linh Xuân',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Linh Trung, Linh Xuân, Linh Tây · Thủ Đức',
  },
  {
    code: 'tang-nhon-phu',
    name: 'Phường Tăng Nhơn Phú',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Tân Phú, Hiệp Phú, Tăng Nhơn Phú A/B · Thủ Đức',
  },
  {
    code: 'long-binh',
    name: 'Phường Long Bình',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Long Bình, Long Thạnh Mỹ · Thủ Đức',
  },
  {
    code: 'long-phuoc',
    name: 'Phường Long Phước',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Trường Thạnh, Long Phước · Thủ Đức',
  },
  {
    code: 'long-truong',
    name: 'Phường Long Trường',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Phú Hữu, Long Trường · Thủ Đức',
  },
  {
    code: 'cat-lai',
    name: 'Phường Cát Lái',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Thạnh Mỹ Lợi, Cát Lái · Thủ Đức',
  },
  {
    code: 'binh-trung',
    name: 'Phường Bình Trưng',
    type: P,
    inDeliveryZone: true,
    lat: 10.785,
    lng: 106.767,
    oldArea: 'Bình Trưng Đông, Bình Trưng Tây, An Phú · Thủ Đức',
  },
  {
    code: 'phuoc-long',
    name: 'Phường Phước Long',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Phước Bình, Phước Long A/B · Thủ Đức',
  },
  {
    code: 'an-khanh',
    name: 'Phường An Khánh',
    type: P,
    inDeliveryZone: true,
    lat: 10.78,
    lng: 106.733,
    oldArea: 'Thủ Thiêm, An Lợi Đông, Thảo Điền, An Khánh, An Phú · Thủ Đức',
  },
  // ── TP.HCM cũ — các xã ──────────────────────────────────────────────
  {
    code: 'vinh-loc',
    name: 'Xã Vĩnh Lộc',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Vĩnh Lộc A, Phạm Văn Hai · Bình Chánh',
  },
  {
    code: 'tan-vinh-loc',
    name: 'Xã Tân Vĩnh Lộc',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Vĩnh Lộc B, Phạm Văn Hai · Bình Chánh',
  },
  {
    code: 'binh-loi',
    name: 'Xã Bình Lợi',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Lê Minh Xuân, Bình Lợi · Bình Chánh',
  },
  {
    code: 'tan-nhut',
    name: 'Xã Tân Nhựt',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Tân Túc, Tân Nhựt, Tân Kiên · Bình Chánh',
  },
  {
    code: 'binh-chanh',
    name: 'Xã Bình Chánh',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Tân Quý Tây, Bình Chánh, An Phú Tây · Bình Chánh',
  },
  {
    code: 'hung-long',
    name: 'Xã Hưng Long',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Đa Phước, Qui Đức, Hưng Long · Bình Chánh',
  },
  {
    code: 'binh-hung',
    name: 'Xã Bình Hưng',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Phong Phú, Bình Hưng · Bình Chánh',
  },
  {
    code: 'binh-khanh',
    name: 'Xã Bình Khánh',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Tam Thôn Hiệp, Bình Khánh · Cần Giờ',
  },
  {
    code: 'an-thoi-dong',
    name: 'Xã An Thới Đông',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Lý Nhơn, An Thới Đông · Cần Giờ',
  },
  {
    code: 'can-gio',
    name: 'Xã Cần Giờ',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Long Hòa, Cần Thạnh · Cần Giờ',
  },
  {
    code: 'thanh-an-can-gio',
    name: 'Xã Thạnh An',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Không sắp xếp · Cần Giờ',
  },
  {
    code: 'cu-chi',
    name: 'Xã Củ Chi',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Tân Phú Trung, Tân Thông Hội, Phước Vĩnh An · Củ Chi',
  },
  {
    code: 'tan-an-hoi',
    name: 'Xã Tân An Hội',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'TT Củ Chi, Phước Hiệp, Tân An Hội · Củ Chi',
  },
  {
    code: 'thai-my',
    name: 'Xã Thái Mỹ',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Trung Lập Thượng, Phước Thạnh, Thái Mỹ · Củ Chi',
  },
  {
    code: 'an-nhon-tay',
    name: 'Xã An Nhơn Tây',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Phú Mỹ Hưng, An Phú, An Nhơn Tây · Củ Chi',
  },
  {
    code: 'nhuan-duc',
    name: 'Xã Nhuận Đức',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Phạm Văn Cội, Trung Lập Hạ, Nhuận Đức · Củ Chi',
  },
  {
    code: 'phu-hoa-dong',
    name: 'Xã Phú Hòa Đông',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Tân Thạnh Tây, Tân Thạnh Đông, Phú Hòa Đông · Củ Chi',
  },
  {
    code: 'binh-my',
    name: 'Xã Bình Mỹ',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Bình Mỹ, Hòa Phú, Trung An · Củ Chi',
  },
  {
    code: 'dong-thanh',
    name: 'Xã Đông Thạnh',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Thới Tam Thôn, Nhị Bình, Đông Thạnh · Hóc Môn',
  },
  {
    code: 'hoc-mon',
    name: 'Xã Hóc Môn',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Tân Hiệp, Tân Xuân, TT Hóc Môn · Hóc Môn',
  },
  {
    code: 'xuan-thoi-son',
    name: 'Xã Xuân Thới Sơn',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Tân Thới Nhì, Xuân Thới Đông, Xuân Thới Sơn · Hóc Môn',
  },
  {
    code: 'ba-diem',
    name: 'Xã Bà Điểm',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Xuân Thới Thượng, Trung Chánh, Bà Điểm · Hóc Môn',
  },
  {
    code: 'nha-be',
    name: 'Xã Nhà Bè',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'TT Nhà Bè, Phú Xuân, Phước Kiển, Phước Lộc · Nhà Bè',
  },
  {
    code: 'hiep-phuoc',
    name: 'Xã Hiệp Phước',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Nhơn Đức, Long Thới, Hiệp Phước · Nhà Bè',
  },
  // ── Khu vực Bình Dương cũ — phường ──────────────────────────────────
  {
    code: 'dong-hoa',
    name: 'Phường Đông Hòa',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Bình An, Bình Thắng, Đông Hòa · Dĩ An, Bình Dương',
  },
  {
    code: 'di-an',
    name: 'Phường Dĩ An',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'An Bình, Dĩ An, Tân Đông Hiệp · Dĩ An, Bình Dương',
  },
  {
    code: 'tan-dong-hiep',
    name: 'Phường Tân Đông Hiệp',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Tân Bình, Thái Hòa, Tân Đông Hiệp · Dĩ An, Bình Dương',
  },
  {
    code: 'an-phu-thuan-an',
    name: 'Phường An Phú',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'An Phú, Bình Chuẩn · Thuận An, Bình Dương',
  },
  {
    code: 'binh-hoa',
    name: 'Phường Bình Hòa',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Bình Hòa, Vĩnh Phú · Thuận An, Bình Dương',
  },
  {
    code: 'lai-thieu',
    name: 'Phường Lái Thiêu',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Bình Nhâm, Lái Thiêu, Vĩnh Phú · Thuận An, Bình Dương',
  },
  {
    code: 'thuan-an',
    name: 'Phường Thuận An',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Hưng Định, An Thạnh, An Sơn · Thuận An, Bình Dương',
  },
  {
    code: 'thuan-giao',
    name: 'Phường Thuận Giao',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Thuận Giao, Bình Chuẩn · Thuận An, Bình Dương',
  },
  {
    code: 'thu-dau-mot',
    name: 'Phường Thủ Dầu Một',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Phú Cường, Phú Thọ, Chánh Nghĩa, Hiệp Thành · Thủ Dầu Một, Bình Dương',
  },
  {
    code: 'phu-loi',
    name: 'Phường Phú Lợi',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Phú Hòa, Phú Lợi, Hiệp Thành · Thủ Dầu Một, Bình Dương',
  },
  {
    code: 'chanh-hiep',
    name: 'Phường Chánh Hiệp',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Định Hòa, Tương Bình Hiệp, Chánh Mỹ · Thủ Dầu Một, Bình Dương',
  },
  {
    code: 'binh-duong',
    name: 'Phường Bình Dương',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Phú Mỹ, Hòa Phú, Phú Tân, Phú Chánh · Thủ Dầu Một, Bình Dương',
  },
  {
    code: 'hoa-loi',
    name: 'Phường Hòa Lợi',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Tân Định, Hòa Lợi · Bến Cát, Bình Dương',
  },
  {
    code: 'phu-an',
    name: 'Phường Phú An',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Tân An, Phú An, Hiệp An · Bến Cát, Bình Dương',
  },
  {
    code: 'tay-nam',
    name: 'Phường Tây Nam',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'An Tây, Thanh Tuyền, An Lập · Bến Cát, Bình Dương',
  },
  {
    code: 'long-nguyen',
    name: 'Phường Long Nguyên',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'An Điền, Long Nguyên, Mỹ Phước · Bến Cát, Bình Dương',
  },
  {
    code: 'ben-cat',
    name: 'Phường Bến Cát',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Tân Hưng, Lai Hưng, Mỹ Phước · Bến Cát, Bình Dương',
  },
  {
    code: 'chanh-phu-hoa',
    name: 'Phường Chánh Phú Hòa',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Chánh Phú Hòa, Hưng Hòa · Bến Cát, Bình Dương',
  },
  {
    code: 'thoi-hoa',
    name: 'Phường Thới Hòa',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Không sắp xếp · Bến Cát, Bình Dương',
  },
  {
    code: 'vinh-tan',
    name: 'Phường Vĩnh Tân',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Vĩnh Tân, TT Tân Bình · Tân Uyên, Bình Dương',
  },
  {
    code: 'binh-co',
    name: 'Phường Bình Cơ',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Bình Mỹ, Hội Nghĩa · Tân Uyên, Bình Dương',
  },
  {
    code: 'tan-uyen',
    name: 'Phường Tân Uyên',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Uyên Hưng, Bạch Đằng, Tân Lập, Tân Mỹ · Tân Uyên, Bình Dương',
  },
  {
    code: 'tan-hiep',
    name: 'Phường Tân Hiệp',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Khánh Bình, Tân Hiệp · Tân Uyên, Bình Dương',
  },
  {
    code: 'tan-khanh',
    name: 'Phường Tân Khánh',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Thạnh Phước, Tân Phước Khánh, Tân Vĩnh Hiệp, Thạnh Hội · Tân Uyên, Bình Dương',
  },
  // ── Khu vực Bình Dương cũ — xã ──────────────────────────────────────
  {
    code: 'thuong-tan',
    name: 'Xã Thường Tân',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Lạc An, Hiếu Liêm, Thường Tân, Tân Mỹ · Bắc Tân Uyên, Bình Dương',
  },
  {
    code: 'bac-tan-uyen',
    name: 'Xã Bắc Tân Uyên',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'TT Tân Thành, Đất Cuốc, Tân Định · Bắc Tân Uyên, Bình Dương',
  },
  {
    code: 'phu-giao',
    name: 'Xã Phú Giáo',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'TT Phước Vĩnh, An Bình, Tam Lập · Phú Giáo, Bình Dương',
  },
  {
    code: 'phuoc-hoa',
    name: 'Xã Phước Hòa',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Vĩnh Hòa, Phước Hòa, Tam Lập · Phú Giáo, Bình Dương',
  },
  {
    code: 'phuoc-thanh',
    name: 'Xã Phước Thành',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Tân Hiệp, An Thái, Phước Sang · Phú Giáo, Bình Dương',
  },
  {
    code: 'an-long',
    name: 'Xã An Long',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'An Linh, Tân Long, An Long · Phú Giáo, Bình Dương',
  },
  {
    code: 'tru-van-tho',
    name: 'Xã Trừ Văn Thố',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Trừ Văn Thố, Cây Trường II, Lai Uyên · Bàu Bàng, Bình Dương',
  },
  {
    code: 'bau-bang',
    name: 'Xã Bàu Bàng',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'TT Lai Uyên · Bàu Bàng, Bình Dương',
  },
  {
    code: 'long-hoa',
    name: 'Xã Long Hòa',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Long Tân, Long Hòa, Minh Tân, Minh Thạnh · Dầu Tiếng, Bình Dương',
  },
  {
    code: 'thanh-an-dau-tieng',
    name: 'Xã Thanh An',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Thanh An, Định Hiệp, Thanh Tuyền, An Lập · Dầu Tiếng, Bình Dương',
  },
  {
    code: 'dau-tieng',
    name: 'Xã Dầu Tiếng',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'TT Dầu Tiếng, Định An, Định Thành, Định Hiệp · Dầu Tiếng, Bình Dương',
  },
  {
    code: 'minh-thanh',
    name: 'Xã Minh Thạnh',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Minh Hòa, Minh Tân, Minh Thạnh · Dầu Tiếng, Bình Dương',
  },
  // ── Khu vực Bà Rịa - Vũng Tàu cũ — phường ──────────────────────────
  {
    code: 'vung-tau',
    name: 'Phường Vũng Tàu',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.1-5, Thắng Nhì, Thắng Tam · TP Vũng Tàu',
  },
  {
    code: 'tam-thang',
    name: 'Phường Tam Thắng',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.7, 8, 9, Nguyễn An Ninh · TP Vũng Tàu',
  },
  {
    code: 'rach-dua',
    name: 'Phường Rạch Dừa',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.10, Thắng Nhất, Rạch Dừa · TP Vũng Tàu',
  },
  {
    code: 'phuoc-thang',
    name: 'Phường Phước Thắng',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'P.11, 12 · TP Vũng Tàu',
  },
  {
    code: 'long-huong',
    name: 'Phường Long Hương',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Tân Hưng, Kim Dinh, Long Hương · TP Bà Rịa',
  },
  {
    code: 'ba-ria',
    name: 'Phường Bà Rịa',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Phước Trung, Phước Nguyên, Long Toàn, Phước Hưng · TP Bà Rịa',
  },
  {
    code: 'tam-long',
    name: 'Phường Tam Long',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Long Tâm, Hòa Long, Long Phước · TP Bà Rịa',
  },
  {
    code: 'tan-hai',
    name: 'Phường Tân Hải',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Tân Hòa, Tân Hải · Phú Mỹ, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'tan-phuoc',
    name: 'Phường Tân Phước',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Phước Hòa, Tân Phước · Phú Mỹ, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'phu-my-ba-ria',
    name: 'Phường Phú Mỹ',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Phú Mỹ, Mỹ Xuân · Phú Mỹ, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'tan-thanh',
    name: 'Phường Tân Thành',
    type: P,
    lat: null,
    lng: null,
    oldArea: 'Hắc Dịch, Sông Xoài · Phú Mỹ, Bà Rịa - Vũng Tàu',
  },
  // ── Khu vực Bà Rịa - Vũng Tàu cũ — xã ───────────────────────────────
  {
    code: 'chau-pha',
    name: 'Xã Châu Pha',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Tóc Tiên, Châu Pha · Phú Mỹ, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'long-son',
    name: 'Xã Long Sơn',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Không sắp xếp · TP Vũng Tàu',
  },
  {
    code: 'long-hai',
    name: 'Xã Long Hải',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'TT Long Hải, Phước Tỉnh, Phước Hưng · Long Đất, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'long-dien',
    name: 'Xã Long Điền',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'TT Long Điền, Tam An · Long Đất, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'phuoc-hai',
    name: 'Xã Phước Hải',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'TT Phước Hải, Phước Hội · Long Đất, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'dat-do',
    name: 'Xã Đất Đỏ',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'TT Đất Đỏ, Long Tân, Láng Dài, Phước Long Thọ · Long Đất, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'nghia-thanh',
    name: 'Xã Nghĩa Thành',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Đá Bạc, Nghĩa Thành · Châu Đức, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'ngai-giao',
    name: 'Xã Ngãi Giao',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'TT Ngãi Giao, Bình Ba, Suối Nghệ · Châu Đức, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'kim-long',
    name: 'Xã Kim Long',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'TT Kim Long, Bàu Chinh, Láng Lớn · Châu Đức, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'chau-duc',
    name: 'Xã Châu Đức',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Cù Bị, Xà Bang · Châu Đức, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'binh-gia',
    name: 'Xã Bình Giã',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Bình Trung, Quảng Thành, Bình Giã · Châu Đức, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'xuan-son',
    name: 'Xã Xuân Sơn',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Suối Rao, Sơn Bình, Xuân Sơn · Châu Đức, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'ho-tram',
    name: 'Xã Hồ Tràm',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'TT Phước Bửu, Phước Tân, Phước Thuận · Xuyên Mộc, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'xuyen-moc',
    name: 'Xã Xuyên Mộc',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Bông Trang, Bưng Riềng, Xuyên Mộc · Xuyên Mộc, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'hoa-hoi',
    name: 'Xã Hòa Hội',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Hòa Hưng, Hòa Bình, Hòa Hội · Xuyên Mộc, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'bau-lam',
    name: 'Xã Bàu Lâm',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Tân Lâm, Bàu Lâm · Xuyên Mộc, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'hoa-hiep',
    name: 'Xã Hòa Hiệp',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Không sắp xếp · Xuyên Mộc, Bà Rịa - Vũng Tàu',
  },
  {
    code: 'binh-chau',
    name: 'Xã Bình Châu',
    type: X,
    lat: null,
    lng: null,
    oldArea: 'Không sắp xếp · Xuyên Mộc, Bà Rịa - Vũng Tàu',
  },
  // ── Đặc khu ─────────────────────────────────────────────────────────
  {
    code: 'con-dao',
    name: 'Đặc khu Côn Đảo',
    type: 'dac-khu',
    lat: null,
    lng: null,
    oldArea: 'Huyện Côn Đảo · Bà Rịa - Vũng Tàu',
  },
];

/**
 * The 102 current wards/communes formed exclusively from the pre-merger
 * Ho Chi Minh City territory. Banan's customer delivery operation is
 * intentionally limited to this footprint; the remaining 66 catalog units
 * belong to former Bình Dương / Bà Rịa - Vũng Tàu (including Côn Đảo).
 *
 * Keep this explicit instead of inferring from `oldArea` display text or
 * coordinates. Neither presentation copy nor geo-data availability is a
 * stable business boundary.
 */
export const FORMER_HCMC_WARD_CODES: ReadonlySet<string> = new Set([
  'sai-gon',
  'tan-dinh',
  'ben-thanh',
  'cau-ong-lanh',
  'ban-co',
  'xuan-hoa',
  'nhieu-loc',
  'xom-chieu',
  'khanh-hoi',
  'vinh-hoi',
  'cho-quan',
  'an-dong',
  'cho-lon',
  'binh-tay',
  'binh-tien',
  'binh-phu',
  'phu-lam',
  'tan-thuan',
  'phu-thuan',
  'tan-my',
  'tan-hung',
  'chanh-hung',
  'phu-dinh',
  'binh-dong',
  'dien-hong',
  'vuon-lai',
  'hoa-hung',
  'minh-phung',
  'binh-thoi',
  'hoa-binh',
  'phu-tho',
  'dong-hung-thuan',
  'trung-my-tay',
  'tan-thoi-hiep',
  'thoi-an',
  'an-phu-dong',
  'an-lac',
  'binh-tan',
  'tan-tao',
  'binh-tri-dong',
  'binh-hung-hoa',
  'gia-dinh',
  'binh-thanh',
  'binh-loi-trung',
  'thanh-my-tay',
  'binh-quoi',
  'hanh-thong',
  'an-nhon',
  'go-vap',
  'an-hoi-dong',
  'thong-tay-hoi',
  'an-hoi-tay',
  'duc-nhuan',
  'cau-kieu',
  'phu-nhuan',
  'tan-son-hoa',
  'tan-son-nhat',
  'tan-hoa',
  'bay-hien',
  'tan-binh',
  'tan-son',
  'tay-thanh',
  'tan-son-nhi',
  'phu-tho-hoa',
  'tan-phu',
  'phu-thanh',
  'hiep-binh',
  'thu-duc',
  'tam-binh',
  'linh-xuan',
  'tang-nhon-phu',
  'long-binh',
  'long-phuoc',
  'long-truong',
  'cat-lai',
  'binh-trung',
  'phuoc-long',
  'an-khanh',
  'vinh-loc',
  'tan-vinh-loc',
  'binh-loi',
  'tan-nhut',
  'binh-chanh',
  'hung-long',
  'binh-hung',
  'binh-khanh',
  'an-thoi-dong',
  'can-gio',
  'thanh-an-can-gio',
  'cu-chi',
  'tan-an-hoi',
  'thai-my',
  'an-nhon-tay',
  'nhuan-duc',
  'phu-hoa-dong',
  'binh-my',
  'dong-thanh',
  'hoc-mon',
  'xuan-thoi-son',
  'ba-diem',
  'nha-be',
  'hiep-phuoc',
]);

/**
 * Codes from the pre-2026 curated catalog whose ward was absorbed WHOLE
 * into exactly one new unit — safe to canonicalize automatically. Never
 * reuse these codes for new wards.
 */
export const LEGACY_WARD_ALIASES: Record<string, string> = {
  // Phường Cầu Kho (Q1) → toàn bộ về Phường Cầu Ông Lãnh.
  'cau-kho': 'cau-ong-lanh',
  // Phường Thảo Điền (Thủ Đức) → toàn bộ về Phường An Khánh mới.
  'thao-dien': 'an-khanh',
  // Slug cũ đặt nhầm cho Phường Diên Hồng (Q10) — cùng một phường.
  'dieu-chi-thang': 'dien-hong',
};

/**
 * Codes of pre-reform wards that were SPLIT between two new units by
 * NQ 1685 — there is no correct automatic mapping, so we never guess:
 * a saved address carrying one of these must be re-selected by the
 * customer. Values list the candidate new wards (for support tooling).
 */
export const AMBIGUOUS_LEGACY_WARDS: Record<string, string[]> = {
  // Phường Đa Kao (Q1) → chia giữa Phường Sài Gòn và Phường Tân Định.
  'da-kao': ['sai-gon', 'tan-dinh'],
  // Phường An Phú (Thủ Đức) → chia giữa Phường An Khánh và Phường Bình
  // Trưng. Code `an-phu` KHÔNG được cấp lại cho Phường An Phú mới của
  // Thuận An (Bình Dương) — phường đó dùng `an-phu-thuan-an`.
  'an-phu': ['an-khanh', 'binh-trung'],
  // Phường Phú Mỹ (Q7) → chia giữa Phường Phú Thuận và Phường Tân Mỹ.
  // Code `phu-my` KHÔNG được cấp lại cho Phường Phú Mỹ mới (Bà Rịa -
  // Vũng Tàu) — dùng `phu-my-ba-ria`.
  'phu-my': ['phu-thuan', 'tan-my'],
};

const byCode = new Map(HCM_WARDS.map((w) => [w.code, w]));

/** True when [code] belongs to a split pre-reform ward that cannot be
 *  auto-mapped — the customer must pick their new ward again. */
export function isAmbiguousLegacyWard(code: string | null | undefined): boolean {
  return code != null && Object.prototype.hasOwnProperty.call(AMBIGUOUS_LEGACY_WARDS, code);
}

/** Resolves a stored code (canonical or safe legacy alias) to its canonical
 *  code. Ambiguous split-ward codes return null — never guessed. */
export function canonicalWardCode(code: string | null | undefined): string | null {
  if (!code) return null;
  if (byCode.has(code)) return code;
  return LEGACY_WARD_ALIASES[code] ?? null;
}

export function findWard(code: string | null | undefined): HcmWard | null {
  const canonical = canonicalWardCode(code);
  if (!canonical) return null;
  return byCode.get(canonical) ?? null;
}

/** Whether a current unit belongs to the pre-merger TP.HCM footprint. */
export function isFormerHcmcWard(wardOrCode: HcmWard | string | null | undefined): boolean {
  if (!wardOrCode) return false;
  const code = typeof wardOrCode === 'string' ? canonicalWardCode(wardOrCode) : wardOrCode.code;
  return code != null && FORMER_HCMC_WARD_CODES.has(code);
}

/** Public delivery-address picker catalog: former TP.HCM only. */
export const FORMER_HCMC_WARDS = HCM_WARDS.filter((ward) => isFormerHcmcWard(ward));

/**
 * A ward is "serviceable" for delivery when the merchant has approved it
 * (`inDeliveryZone`) AND we have a verified centroid to route from. The
 * two are checked together on purpose: policy without geo cannot route,
 * geo without policy must not open the zone. Non-serviceable wards are
 * still VALID catalog entries (picker, addresses, pickup orders) —
 * checkout shows "chưa hỗ trợ giao đến khu vực này" instead of treating
 * them as unknown.
 */
export function isWardServiceable(ward: HcmWard | null | undefined): boolean {
  return (
    isFormerHcmcWard(ward) && ward?.inDeliveryZone === true && ward.lat != null && ward.lng != null
  );
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
  const x = Math.sin(dLat / 2) ** 2 + Math.sin(dLng / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);
  return 2 * R * Math.asin(Math.sqrt(x));
}

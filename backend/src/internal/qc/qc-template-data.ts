/**
 * The default QC template, transcribed VERBATIM from the paper form
 * "BANAN FUKUOKA SAIGON: QA - QC Checklist" (QC Checklist.pdf).
 *
 * Fidelity rules (agreed with ops):
 * - Item texts are copied exactly as printed — including the PDF's own typo
 *   "bảo dưỡng tố" in Water closet #5. Do not "fix" wording here; a wording
 *   change is a new template version.
 * - `sourceRef` is the STT as PRINTED on the form. Bar Area is printed
 *   1–7 then 9 (there is no visible item 8), so its refs are '1'..'7','9'
 *   while the app displays its own sequential numbering. Never invent an
 *   item 8.
 * - The paper form's printed totals (/40 overall, /9 for Bar Area) do NOT
 *   match the visible items (48 normal items, 8 in Bar Area). Scoring is
 *   therefore computed dynamically from the seeded items — no hard-coded
 *   maximum anywhere.
 * - RISK items are not scored; any RISK = "Có" fails the whole checklist
 *   (CRITICAL_FAIL), per the form's NOTE 1.
 */

export interface QcTemplateSeedItem {
  sourceRef: string;
  text: string;
}

export interface QcTemplateSeedSection {
  title: string;
  isRisk: boolean;
  items: QcTemplateSeedItem[];
}

export const QC_TEMPLATE_NAME = 'BANAN FUKUOKA SAIGON: QA - QC Checklist';
export const QC_TEMPLATE_VERSION = 1;

/** Both section thresholds from the form's NOTE 2/3: below 80% fails. */
export const QC_PASS_THRESHOLD_PERCENT = 80;

export const QC_TEMPLATE_SECTIONS: QcTemplateSeedSection[] = [
  {
    title: 'RECEIVING & STORING - NHẬN & BẢO QUẢN HÀNG HÓA',
    isRisk: false,
    items: [
      { sourceRef: '1', text: 'Ngoại quan: Màu sắc, cấu trúc đạt yêu cầu.' },
      { sourceRef: '2', text: 'Quy cách: kích thước, cân nặng, đóng gói đạt yêu cầu.' },
      { sourceRef: '3', text: 'Bao bì, nhãn mác: đầy đủ, đúng quy định' },
      { sourceRef: '4', text: 'Thiết bị bảo quản đúng quy định: Bảo quản lạnh, thường v.v...' },
      { sourceRef: '5', text: 'Chứng từ: Điều chuyển, giao hàng đầy đủ' },
    ],
  },
  {
    title: 'HOLDING - TỔ CHỨC BẢO QUẢN HÀNG HÓA',
    isRisk: false,
    items: [
      { sourceRef: '1', text: 'Dụng cụ bảo quản sạch sẽ, bảo dưỡng tốt' },
      { sourceRef: '2', text: 'Nhiệt độ tủ, kho đảm bảo: Có ghi biểu mẫu nhiệt độ hàng ngày' },
      { sourceRef: '3', text: 'Bên ngoài mặt tủ sạch sẽ' },
      { sourceRef: '4', text: 'NVL, sản phẩm được bao gói đúng quy định: wrap, đậy v.v…' },
      {
        sourceRef: '5',
        text: 'NVL, sản phẩm sắp xếp đúng quy định: không để trực tiếp trên sàn; Đựng chung nvl không có màng ngăn cách',
      },
      { sourceRef: '6', text: 'Tem nhãn đầy đủ: NVL, BTP có tem nhãn ngày giờ đầy đủ' },
      {
        sourceRef: '7',
        text: 'Không có sản phẩm hết hạn sử dụng. SP còn dưới 30% HSD phải được báo với quản lý',
      },
      { sourceRef: '8', text: 'Tủ bảo quản, kho bảo quản: có label định danh các kệ' },
    ],
  },
  {
    title: 'Cleaning System - Hygiene System',
    isRisk: false,
    items: [
      { sourceRef: '1', text: 'Dụng cụ vệ sinh đầy đủ, hoạt động tốt. bảo dưỡng tốt' },
      { sourceRef: '2', text: 'Hóa chất vệ sinh đầy đủ' },
      {
        sourceRef: '3',
        text: 'Thực hành vệ sinh đầy đủ: Hàng ngày - Hàng tuần theo lịch SM, có lưu checklist & báo cáo',
      },
      { sourceRef: '4', text: 'Tài liệu hướng dẫn vệ sinh: có lưu trong CH' },
      { sourceRef: '5', text: 'Hóa chất & dụng cụ vệ sinh để đúng nơi quy định' },
      {
        sourceRef: '6',
        text: 'Pets control: không có côn trùng; Dịch vụ côn trùng có hoạt động trong 2 tháng gần nhất',
      },
    ],
  },
  {
    title: 'Front House - Customer Area Hygiene',
    isRisk: false,
    items: [
      { sourceRef: '1', text: 'Lối vào/Bãi xe sạch sẽ, bảo dưỡng tốt' },
      {
        sourceRef: '2',
        text: 'Sân vườn/cây trang trí/bàn trang trí/tiểu cảnh: sạch sẽ, bảo dưỡng tốt',
      },
      { sourceRef: '3', text: 'Bảng hiệu/Bảng quảng cáo: Sạch sẽ, bảo dưỡng tốt' },
      { sourceRef: '4', text: 'Cửa chính/Cửa sổ: Sạch sẽ, bảo dưỡng tốt' },
      { sourceRef: '5', text: 'Khu vực khách ngồi thoáng mát, không côn trùng, không có mùi lạ' },
      { sourceRef: '6', text: 'Bàn/Ghế/Salon/Đệm/Sofa: Sạch sẽ, không bị kênh, bảo dưỡng tốt' },
      { sourceRef: '7', text: 'Sàn nhà/lối đi/cầu thang: Sạch sẽ, bảo dưỡng tốt' },
      {
        sourceRef: '8',
        text: 'Khu vực check-in/cashier: Sạch sẽ, bảo dưỡng tốt. Không có vật dụng cá nhân trong tầm mắt khách hàng',
      },
      { sourceRef: '9', text: 'Trần/Tường/Đèn sạch sẽ, bảo dưỡng tốt' },
      {
        sourceRef: '10',
        text: 'Quầy vệ sinh/Thùng rác/Tủ bên ngoài/Giỏ đựng đồ cho khách: Sạch sẽ, bảo dưỡng tốt',
      },
    ],
  },
  {
    title: 'Bar Area',
    isRisk: false,
    // Printed 1–7 then 9 — 8 real items; see the header comment.
    items: [
      { sourceRef: '1', text: 'Sàn/Tường/Trần: Sạch sẽ, bảo dưỡng tốt' },
      { sourceRef: '2', text: 'Bàn pha chế/Thùng đá/Tủ đá: Sạch sẽ, bảo dưỡng tốt' },
      { sourceRef: '3', text: 'CCDC pha chế/Máy móc: Sạch sẽ, bảo dưỡng tốt' },
      { sourceRef: '4', text: 'Tủ lạnh/Tủ đông: Sạch sẽ, bảo dưỡng tốt' },
      { sourceRef: '5', text: 'Bồn rửa/Bên dưới bồn rửa: Sạch sẽ, bảo dưỡng tốt' },
      { sourceRef: '6', text: 'Cống rãnh: Không có mùi hôi' },
      { sourceRef: '7', text: 'Thùng rác: Sạch sẽ/ có nắp đậy' },
      { sourceRef: '9', text: 'CCDC phục vụ: Đầy đủ, sạch sẽ, sẵn sàng phục vụ' },
    ],
  },
  {
    title: 'Water closet - Nhà Vệ Sinh',
    isRisk: false,
    items: [
      {
        sourceRef: '1',
        text: 'Không khí thoáng mát, không bụi bẩn, mùi tự nhiên, không có mùi hôi',
      },
      { sourceRef: '2', text: 'Sàn/Tường/Trần: Sạch sẽ, bảo dưỡng tốt' },
      { sourceRef: '3', text: 'Bồn vệ sinh: Sạch sẽ, bảo dưỡng tốt' },
      { sourceRef: '4', text: 'Thùng rác: Sạch sẽ/ có nắp đậy/ không đầy tràn' },
      // "tố" is the form's own typo — kept verbatim on purpose.
      { sourceRef: '5', text: 'Mặt bàn/ kính/ Bồn rửa tay: Sạch sẽ, bảo dưỡng tố' },
      {
        sourceRef: '6',
        text: 'Giấy vệ sinh, nước rửa tay đầy đủ (Chi nhánh SVH phải có tăm, giấy lau kính, nước súc miệng v.v…)',
      },
    ],
  },
  {
    title: 'Product Safety - Safe Food Serving',
    isRisk: false,
    items: [
      { sourceRef: '1', text: 'Sản phẩm bánh: Được chuẩn bị & phục vụ đúng hướng dẫn' },
      { sourceRef: '2', text: 'Sản phẩm nước: Được pha chế, phục vụ đúng hướng dẫn' },
      { sourceRef: '3', text: 'Bánh/nước được phục vụ đúng theo yêu cầu của khách' },
      { sourceRef: '4', text: 'Nhân viên đầy đủ đồng phục, tác phong đúng theo quy định công ty' },
      {
        sourceRef: '5',
        text: '75% đơn hàng Dine-in trong ngày/tuần được lấy feedback của khách thông qua QR',
      },
    ],
  },
  {
    title: 'RISK',
    isRisk: true,
    items: [
      { sourceRef: '1', text: 'Có lưu trữ sản phẩm/BTP hết hạn sử dụng' },
      {
        sourceRef: '2',
        text: 'Có lưu trữ sản phẩm/BTP hư, mốc & không được dán nhãn nhận diện hoặc tách riêng chờ kiểm tra',
      },
      { sourceRef: '3', text: 'Sản phẩm có dấu hiệu lây nhiễm chéo' },
      { sourceRef: '4', text: 'Phục vụ món ăn/đồ uống sai quy trình/không đúng option của khách' },
    ],
  },
];

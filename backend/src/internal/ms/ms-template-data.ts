/**
 * Default Mystery Shopper checklist — 100 weighted points across 8 scored
 * groups (A–H) plus the unweighted CRITICAL group. Per-question N/A is only
 * allowed where flagged (the WC question); an N/A question leaves its
 * group's denominator, and the group score is normalised over the remaining
 * applicable questions before the weight is applied.
 */

export interface MsSeedQuestion {
  text: string;
  allowNa?: boolean;
}

export interface MsSeedSection {
  code: string;
  title: string;
  kind: 'SCORED' | 'CRITICAL';
  weight: number;
  questions: MsSeedQuestion[];
}

export const MS_TEMPLATE_NAME = 'Banan Mystery Shopper Checklist';
export const MS_TEMPLATE_VERSION = 1;

export const MS_TEMPLATE_SECTIONS: MsSeedSection[] = [
  {
    code: 'A',
    title: 'Tiếp cận cửa hàng',
    kind: 'SCORED',
    weight: 5,
    questions: [
      { text: 'Ngoại quan và lối vào sạch, dễ tiếp cận.' },
      { text: 'Ấn tượng ban đầu phù hợp thương hiệu.' },
    ],
  },
  {
    code: 'B',
    title: 'Chào đón và thái độ',
    kind: 'SCORED',
    weight: 15,
    questions: [
      { text: 'Nhân viên chủ động chào khách.' },
      { text: 'Thái độ thân thiện và lịch sự.' },
      { text: 'Chủ động hỗ trợ khi khách cần.' },
      { text: 'Đồng phục và tác phong phù hợp.' },
    ],
  },
  {
    code: 'C',
    title: 'Tư vấn sản phẩm',
    kind: 'SCORED',
    weight: 15,
    questions: [
      { text: 'Hỏi hoặc hiểu nhu cầu khách.' },
      { text: 'Giải thích sản phẩm rõ ràng.' },
      { text: 'Tư vấn sản phẩm phù hợp.' },
      { text: 'Trả lời thông tin thành phần/dị ứng có trách nhiệm.' },
      { text: 'Không ép mua hoặc tư vấn gây khó chịu.' },
    ],
  },
  {
    code: 'D',
    title: 'Đặt hàng và thanh toán',
    kind: 'SCORED',
    weight: 15,
    questions: [
      { text: 'Ghi nhận đúng món.' },
      { text: 'Ghi nhận đúng option/yêu cầu.' },
      { text: 'Giá thanh toán chính xác.' },
      { text: 'Quy trình thanh toán rõ ràng.' },
      { text: 'Cung cấp hóa đơn khi cần.' },
      { text: 'Thời gian chờ hợp lý.' },
    ],
  },
  {
    code: 'E',
    title: 'Chất lượng sản phẩm',
    kind: 'SCORED',
    weight: 25,
    questions: [
      { text: 'Ngoại quan đúng chuẩn.' },
      { text: 'Hương vị đạt yêu cầu.' },
      { text: 'Kết cấu đạt yêu cầu.' },
      { text: 'Nhiệt độ phục vụ phù hợp.' },
      { text: 'Đóng gói sạch và chắc chắn.' },
      { text: 'Sản phẩm đúng món và đúng option.' },
    ],
  },
  {
    code: 'F',
    title: 'Vệ sinh và không gian',
    kind: 'SCORED',
    weight: 15,
    questions: [
      { text: 'Quầy và khu vực khách nhìn thấy sạch.' },
      { text: 'Bàn ghế sạch.' },
      { text: 'Sàn/lối đi sạch.' },
      { text: 'Không có mùi khó chịu/côn trùng.' },
      // The only question where N/A is legal — and it must carry a reason.
      { text: 'Nhà vệ sinh sạch và đủ vật dụng (nếu có sử dụng).', allowNa: true },
    ],
  },
  {
    code: 'G',
    title: 'Kết thúc trải nghiệm',
    kind: 'SCORED',
    weight: 5,
    questions: [
      { text: 'Giao món rõ ràng, đúng khách.' },
      { text: 'Nhân viên cảm ơn/chào khách.' },
      { text: 'Xử lý vấn đề phát sinh phù hợp.', allowNa: true },
    ],
  },
  {
    code: 'H',
    title: 'Đánh giá tổng quan',
    kind: 'SCORED',
    weight: 5,
    questions: [
      { text: 'Mức độ sẵn sàng quay lại.' },
      { text: 'Mức độ sẵn sàng giới thiệu Banan.' },
    ],
  },
  {
    code: 'CRIT',
    title: 'Lỗi nghiêm trọng (Critical Fail)',
    kind: 'CRITICAL',
    weight: 0,
    questions: [
      { text: 'Thông tin dị ứng sai hoặc xử lý thiếu trách nhiệm.' },
      { text: 'Thu sai tiền hoặc giá không đúng.' },
      { text: 'Sản phẩm có dấu hiệu hư/mốc/mất an toàn.' },
      { text: 'Phục vụ sai món hoặc sai option quan trọng.' },
      { text: 'Thái độ xúc phạm, gây gổ hoặc phân biệt đối xử.' },
    ],
  },
];

/**
 * "Điều làm tốt nhất" / "Điều cần cải thiện nhất" from group H are free-text
 * prompts, not scorable YES/NO questions — they live on the submission's
 * overall comment fields, so H scores only its two YES/NO questions.
 */
export const MS_TOTAL_WEIGHT = MS_TEMPLATE_SECTIONS.filter((s) => s.kind === 'SCORED').reduce(
  (sum, s) => sum + s.weight,
  0,
);

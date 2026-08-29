/**
 * Default dine-in survey template (VI + EN), version 1. Seeded once by
 * `internal-seed.ts` — production edits happen through the survey editor as
 * NEW versions, never by re-running the seed.
 *
 * Question `code`s are the stable semantic keys the case rule, conditional
 * display and reporting hang off ('overall' drives the ≤2 case + ≤3/≥4
 * branching; 'improve'/'praise' feed the top-issue charts).
 */

export const SURVEY_TEMPLATE_NAME = 'Khảo sát trải nghiệm tại quán';
export const SURVEY_TEMPLATE_VERSION = 1;

export interface SurveyOptionSeed {
  value: string;
  labelVi: string;
  labelEn: string;
}

export interface SurveyQuestionSeed {
  code: string;
  type: 'EMOJI_SCALE' | 'RATING' | 'NPS' | 'SINGLE_CHOICE' | 'MULTI_CHOICE' | 'TEXT' | 'YES_NO';
  textVi: string;
  textEn: string;
  required?: boolean;
  maxLength?: number;
  showIfQuestionCode?: string;
  showIfOp?: 'LTE' | 'GTE' | 'EQ';
  showIfValue?: number;
  options?: SurveyOptionSeed[];
}

export const SURVEY_TEMPLATE_QUESTIONS: SurveyQuestionSeed[] = [
  {
    code: 'overall',
    type: 'EMOJI_SCALE',
    textVi: 'Trải nghiệm tại Banan hôm nay thế nào?',
    textEn: 'How was your experience at Banan today?',
    required: true,
  },
  {
    code: 'food_drink',
    type: 'RATING',
    textVi: 'Bánh / đồ uống',
    textEn: 'Food & drinks',
  },
  {
    code: 'service_attitude',
    type: 'RATING',
    textVi: 'Thái độ phục vụ',
    textEn: 'Service attitude',
  },
  {
    code: 'service_speed',
    type: 'RATING',
    textVi: 'Tốc độ phục vụ',
    textEn: 'Service speed',
  },
  {
    code: 'space_clean',
    type: 'RATING',
    textVi: 'Không gian & vệ sinh',
    textEn: 'Space & cleanliness',
  },
  {
    code: 'improve',
    type: 'MULTI_CHOICE',
    textVi: 'Banan cần cải thiện điều gì?',
    textEn: 'What should Banan improve?',
    showIfQuestionCode: 'overall',
    showIfOp: 'LTE',
    showIfValue: 3,
    options: [
      { value: 'taste', labelVi: 'Hương vị', labelEn: 'Taste' },
      { value: 'freshness', labelVi: 'Độ tươi / nhiệt độ', labelEn: 'Freshness / temperature' },
      { value: 'presentation', labelVi: 'Trình bày', labelEn: 'Presentation' },
      { value: 'speed', labelVi: 'Tốc độ phục vụ', labelEn: 'Service speed' },
      { value: 'staff_attitude', labelVi: 'Thái độ nhân viên', labelEn: 'Staff attitude' },
      { value: 'hygiene', labelVi: 'Vệ sinh', labelEn: 'Hygiene' },
      { value: 'out_of_stock', labelVi: 'Món không có sẵn', labelEn: 'Items unavailable' },
      { value: 'payment', labelVi: 'Thanh toán', labelEn: 'Payment' },
      { value: 'other', labelVi: 'Khác', labelEn: 'Other' },
    ],
  },
  {
    code: 'praise',
    type: 'MULTI_CHOICE',
    textVi: 'Điều gì làm bạn thích nhất?',
    textEn: 'What did you like most?',
    showIfQuestionCode: 'overall',
    showIfOp: 'GTE',
    showIfValue: 4,
    options: [
      { value: 'taste', labelVi: 'Hương vị bánh & đồ uống', labelEn: 'Taste of food & drinks' },
      { value: 'freshness', labelVi: 'Bánh tươi, chất lượng', labelEn: 'Freshness & quality' },
      { value: 'presentation', labelVi: 'Trình bày đẹp', labelEn: 'Beautiful presentation' },
      { value: 'speed', labelVi: 'Phục vụ nhanh', labelEn: 'Quick service' },
      { value: 'staff', labelVi: 'Nhân viên thân thiện', labelEn: 'Friendly staff' },
      { value: 'space', labelVi: 'Không gian dễ chịu', labelEn: 'Cozy space' },
      { value: 'value', labelVi: 'Giá trị xứng đáng', labelEn: 'Good value' },
      { value: 'other', labelVi: 'Khác', labelEn: 'Other' },
    ],
  },
  {
    code: 'nps',
    type: 'NPS',
    textVi: 'Bạn có sẵn lòng giới thiệu Banan cho bạn bè?',
    textEn: 'How likely are you to recommend Banan to a friend?',
  },
  {
    code: 'comment',
    type: 'TEXT',
    textVi: 'Góp ý thêm cho Banan',
    textEn: 'Anything else you would like to share?',
    maxLength: 1000,
  },
  {
    code: 'contact_request',
    type: 'YES_NO',
    textVi: 'Bạn có muốn Banan liên hệ để xử lý vấn đề không?',
    textEn: 'Would you like Banan to contact you about this?',
    showIfQuestionCode: 'overall',
    showIfOp: 'LTE',
    showIfValue: 2,
  },
];

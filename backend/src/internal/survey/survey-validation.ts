import { BadRequestException } from '@nestjs/common';

/**
 * Pure server-side validation of a public survey submission against the
 * template's questions — required, per-type value ranges, option membership
 * and conditional-display rules. Pure so the whole matrix is unit-testable
 * without a database.
 */

export interface SurveyQuestionShape {
  id: string;
  code: string;
  type: string;
  required: boolean;
  sortOrder: number;
  maxLength: number | null;
  showIfQuestionCode: string | null;
  showIfOp: string | null;
  showIfValue: number | null;
  options: { value: string }[];
}

export interface SubmittedSurveyAnswer {
  questionId: string;
  numberValue?: number | null;
  textValue?: string | null;
  optionValues?: string[] | null;
}

export interface CleanSurveyAnswer {
  questionId: string;
  questionCode: string;
  numberValue: number | null;
  textValue: string | null;
  optionValues: string[];
}

function bad(code: string, message: string, questionCode?: string): never {
  throw new BadRequestException({
    code,
    message,
    ...(questionCode ? { details: [{ questionCode }] } : {}),
  });
}

function numberRange(type: string): [number, number] | null {
  switch (type) {
    case 'EMOJI_SCALE':
    case 'RATING':
      return [1, 5];
    case 'NPS':
      return [0, 10];
    case 'YES_NO':
      return [0, 1];
    default:
      return null;
  }
}

/** True when the question is visible given the numeric answers by code. */
export function surveyQuestionVisible(
  q: Pick<SurveyQuestionShape, 'showIfQuestionCode' | 'showIfOp' | 'showIfValue'>,
  numericByCode: Map<string, number>,
): boolean {
  if (!q.showIfQuestionCode || !q.showIfOp || q.showIfValue == null) return true;
  const answered = numericByCode.get(q.showIfQuestionCode);
  if (answered == null) return false;
  switch (q.showIfOp) {
    case 'LTE':
      return answered <= q.showIfValue;
    case 'GTE':
      return answered >= q.showIfValue;
    case 'EQ':
      return answered === q.showIfValue;
    default:
      return false;
  }
}

/**
 * Validates + normalizes the submitted answers. Returns the clean rows to
 * persist and the overall emoji score (the code "overall" question). Throws
 * BadRequestException with a stable `code` (+ the offending questionCode in
 * details) on any violation.
 */
export function validateSurveyAnswers(
  questions: SurveyQuestionShape[],
  submitted: SubmittedSurveyAnswer[],
): { clean: CleanSurveyAnswer[]; overall: number | null } {
  const byId = new Map(questions.map((q) => [q.id, q]));

  // Parse + de-noise (an all-empty answer row is treated as absent).
  const seen = new Set<string>();
  const parsed = new Map<string, CleanSurveyAnswer>();
  for (const a of submitted) {
    const q = byId.get(a.questionId);
    if (!q) bad('SURVEY_INVALID_QUESTION', 'Câu hỏi không thuộc mẫu khảo sát này.');
    if (seen.has(a.questionId)) {
      bad('SURVEY_DUPLICATE_ANSWER', 'Mỗi câu hỏi chỉ trả lời một lần.', q.code);
    }
    seen.add(a.questionId);

    const text = a.textValue?.trim() || null;
    const opts = (a.optionValues ?? []).filter((v) => v.length > 0);
    const num = a.numberValue ?? null;
    if (num == null && !text && opts.length === 0) continue; // skipped question

    const range = numberRange(q.type);
    if (range) {
      if (num == null || text || opts.length > 0) {
        bad('SURVEY_ANSWER_INVALID', 'Câu trả lời không hợp lệ.', q.code);
      }
      if (num < range[0] || num > range[1]) {
        bad('SURVEY_ANSWER_INVALID', 'Giá trị ngoài thang điểm.', q.code);
      }
      parsed.set(q.id, {
        questionId: q.id,
        questionCode: q.code,
        numberValue: num,
        textValue: null,
        optionValues: [],
      });
      continue;
    }
    if (q.type === 'TEXT') {
      if (num != null || opts.length > 0 || !text) {
        bad('SURVEY_ANSWER_INVALID', 'Câu trả lời không hợp lệ.', q.code);
      }
      const max = q.maxLength ?? 1000;
      if (text.length > max) {
        bad('SURVEY_ANSWER_TOO_LONG', `Góp ý tối đa ${max} ký tự.`, q.code);
      }
      parsed.set(q.id, {
        questionId: q.id,
        questionCode: q.code,
        numberValue: null,
        textValue: text,
        optionValues: [],
      });
      continue;
    }
    if (q.type === 'SINGLE_CHOICE' || q.type === 'MULTI_CHOICE') {
      if (num != null || text || opts.length === 0) {
        bad('SURVEY_ANSWER_INVALID', 'Câu trả lời không hợp lệ.', q.code);
      }
      const allowed = new Set(q.options.map((o) => o.value));
      const unique = [...new Set(opts)];
      if (unique.some((v) => !allowed.has(v))) {
        bad('SURVEY_ANSWER_INVALID', 'Lựa chọn không hợp lệ.', q.code);
      }
      if (q.type === 'SINGLE_CHOICE' && unique.length !== 1) {
        bad('SURVEY_ANSWER_INVALID', 'Chỉ chọn một lựa chọn.', q.code);
      }
      parsed.set(q.id, {
        questionId: q.id,
        questionCode: q.code,
        numberValue: null,
        textValue: null,
        optionValues: unique,
      });
      continue;
    }
    bad('SURVEY_ANSWER_INVALID', 'Câu trả lời không hợp lệ.', q.code);
  }

  // Conditional visibility off the NUMERIC answers.
  const numericByCode = new Map<string, number>();
  for (const c of parsed.values()) {
    if (c.numberValue != null) numericByCode.set(c.questionCode, c.numberValue);
  }
  for (const q of questions) {
    const visible = surveyQuestionVisible(q, numericByCode);
    const answered = parsed.has(q.id);
    if (!visible && answered) {
      bad('SURVEY_CONDITIONAL_VIOLATION', 'Câu trả lời không khớp điều kiện hiển thị.', q.code);
    }
    if (visible && q.required && !answered) {
      bad('SURVEY_REQUIRED_MISSING', 'Thiếu câu trả lời bắt buộc.', q.code);
    }
  }

  // THE system code, never "first emoji question" — a custom EMOJI_SCALE an
  // admin adds before it must not become what opens cases and fires alerts.
  // (Publish enforces that code "overall" exists, is EMOJI_SCALE, required.)
  const overallQ = questions.find((q) => q.code === 'overall' && q.type === 'EMOJI_SCALE');
  const overall = overallQ ? (parsed.get(overallQ.id)?.numberValue ?? null) : null;

  return { clean: [...parsed.values()], overall };
}

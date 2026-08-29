import { BadRequestException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

import { IS_PUBLIC_KEY } from '../../auth/decorators/public.decorator';
import { ROLES_KEY } from '../../auth/decorators/roles.decorator';

import { PublicSurveySubmitDto, SurveyReportQueryDto } from './dto';
import { SurveyPublicController } from './survey-public.controller';
import { SURVEY_TEMPLATE_QUESTIONS } from './survey-template-data';
import { validateSurveyAnswers, type SurveyQuestionShape } from './survey-validation';
import { SurveyController } from './survey.controller';
import { csvField, normalizeVnPhone, vnDayKey } from './survey.service';

const reflector = new Reflector();

// ── role surface ────────────────────────────────────────────────────────────

describe('survey role surface (metadata)', () => {
  it('admin controller is ADMIN-only at class level (guests + TRAINEE stay out)', () => {
    expect(reflector.get<Role[]>(ROLES_KEY, SurveyController)).toEqual([Role.ADMIN]);
  });

  it('public controller endpoints are @Public', () => {
    expect(reflector.get<boolean>(IS_PUBLIC_KEY, SurveyPublicController.prototype.info)).toBe(true);
    expect(reflector.get<boolean>(IS_PUBLIC_KEY, SurveyPublicController.prototype.submit)).toBe(
      true,
    );
  });

  it('public controller itself carries NO roles metadata (nothing to escalate)', () => {
    expect(reflector.get<Role[]>(ROLES_KEY, SurveyPublicController)).toBeUndefined();
  });
});

// ── answer validation (pure) ────────────────────────────────────────────────

/** Default template questions with synthetic ids — the real seed shape. */
function questions(): SurveyQuestionShape[] {
  return SURVEY_TEMPLATE_QUESTIONS.map((q, idx) => ({
    id: `q-${q.code}`,
    code: q.code,
    type: q.type,
    required: q.required ?? false,
    sortOrder: idx,
    maxLength: q.maxLength ?? null,
    showIfQuestionCode: q.showIfQuestionCode ?? null,
    showIfOp: q.showIfOp ?? null,
    showIfValue: q.showIfValue ?? null,
    options: (q.options ?? []).map((o) => ({ value: o.value })),
  }));
}

function codeOf(err: unknown): string {
  const res = (err as BadRequestException).getResponse() as { code: string };
  return res.code;
}

describe('validateSurveyAnswers', () => {
  const qs = questions();

  it('happy path (positive branch): overall 5 + praise + nps + comment', () => {
    const { clean, overall } = validateSurveyAnswers(qs, [
      { questionId: 'q-overall', numberValue: 5 },
      { questionId: 'q-food_drink', numberValue: 4 },
      { questionId: 'q-praise', optionValues: ['taste', 'staff'] },
      { questionId: 'q-nps', numberValue: 10 },
      { questionId: 'q-comment', textValue: 'Bánh ngon lắm!' },
    ]);
    expect(overall).toBe(5);
    expect(clean).toHaveLength(5);
  });

  it('negative branch: overall 2 allows improve + contact_request', () => {
    const { overall } = validateSurveyAnswers(qs, [
      { questionId: 'q-overall', numberValue: 2 },
      { questionId: 'q-improve', optionValues: ['speed', 'hygiene'] },
      { questionId: 'q-contact_request', numberValue: 1 },
    ]);
    expect(overall).toBe(2);
  });

  it('missing required overall is rejected', () => {
    expect.assertions(1);
    try {
      validateSurveyAnswers(qs, [{ questionId: 'q-nps', numberValue: 8 }]);
    } catch (e) {
      expect(codeOf(e)).toBe('SURVEY_REQUIRED_MISSING');
    }
  });

  it('praise answered on a LOW score violates the conditional rule', () => {
    expect.assertions(1);
    try {
      validateSurveyAnswers(qs, [
        { questionId: 'q-overall', numberValue: 2 },
        { questionId: 'q-praise', optionValues: ['taste'] },
      ]);
    } catch (e) {
      expect(codeOf(e)).toBe('SURVEY_CONDITIONAL_VIOLATION');
    }
  });

  it('improve answered on a HIGH score violates the conditional rule', () => {
    expect.assertions(1);
    try {
      validateSurveyAnswers(qs, [
        { questionId: 'q-overall', numberValue: 5 },
        { questionId: 'q-improve', optionValues: ['taste'] },
      ]);
    } catch (e) {
      expect(codeOf(e)).toBe('SURVEY_CONDITIONAL_VIOLATION');
    }
  });

  it('contact_request is hidden at overall 3 (only <= 2 shows it)', () => {
    expect.assertions(1);
    try {
      validateSurveyAnswers(qs, [
        { questionId: 'q-overall', numberValue: 3 },
        { questionId: 'q-improve', optionValues: ['taste'] },
        { questionId: 'q-contact_request', numberValue: 1 },
      ]);
    } catch (e) {
      expect(codeOf(e)).toBe('SURVEY_CONDITIONAL_VIOLATION');
    }
  });

  it('unknown question id is rejected', () => {
    expect.assertions(1);
    try {
      validateSurveyAnswers(qs, [{ questionId: 'q-hack', numberValue: 5 }]);
    } catch (e) {
      expect(codeOf(e)).toBe('SURVEY_INVALID_QUESTION');
    }
  });

  it('out-of-range emoji / nps values are rejected', () => {
    expect(() => validateSurveyAnswers(qs, [{ questionId: 'q-overall', numberValue: 6 }])).toThrow(
      BadRequestException,
    );
    expect(() =>
      validateSurveyAnswers(qs, [
        { questionId: 'q-overall', numberValue: 5 },
        { questionId: 'q-nps', numberValue: 11 },
      ]),
    ).toThrow(BadRequestException);
  });

  it('option outside the question option set is rejected', () => {
    expect.assertions(1);
    try {
      validateSurveyAnswers(qs, [
        { questionId: 'q-overall', numberValue: 2 },
        { questionId: 'q-improve', optionValues: ['free_cake'] },
      ]);
    } catch (e) {
      expect(codeOf(e)).toBe('SURVEY_ANSWER_INVALID');
    }
  });

  it('comment over its maxLength is rejected', () => {
    expect.assertions(1);
    try {
      validateSurveyAnswers(qs, [
        { questionId: 'q-overall', numberValue: 4 },
        { questionId: 'q-comment', textValue: 'x'.repeat(1001) },
      ]);
    } catch (e) {
      expect(codeOf(e)).toBe('SURVEY_ANSWER_TOO_LONG');
    }
  });

  it('duplicate answers to one question are rejected', () => {
    expect.assertions(1);
    try {
      validateSurveyAnswers(qs, [
        { questionId: 'q-overall', numberValue: 4 },
        { questionId: 'q-overall', numberValue: 5 },
      ]);
    } catch (e) {
      expect(codeOf(e)).toBe('SURVEY_DUPLICATE_ANSWER');
    }
  });

  it('overall comes from the code "overall", never the first emoji question', () => {
    const customFirst: SurveyQuestionShape = {
      id: 'q-mood',
      code: 'mood',
      type: 'EMOJI_SCALE',
      required: false,
      sortOrder: -1,
      maxLength: null,
      showIfQuestionCode: null,
      showIfOp: null,
      showIfValue: null,
      options: [],
    };
    const { overall } = validateSurveyAnswers(
      [customFirst, ...qs],
      [
        { questionId: 'q-mood', numberValue: 1 },
        { questionId: 'q-overall', numberValue: 5 },
      ],
    );
    // A custom emoji scoring 1 must NOT open a case — overall is 5.
    expect(overall).toBe(5);
  });

  it('empty answer rows are dropped as skipped, optional questions may be skipped', () => {
    const { clean } = validateSurveyAnswers(qs, [
      { questionId: 'q-overall', numberValue: 4 },
      { questionId: 'q-food_drink' },
      { questionId: 'q-comment', textValue: '   ' },
    ]);
    expect(clean).toHaveLength(1);
  });
});

// ── submit DTO whitelist ────────────────────────────────────────────────────

describe('PublicSurveySubmitDto', () => {
  const base = {
    templateId: '7b9d75a2-9f7e-4bde-a3a6-9a5f0e5c1111',
    storeId: '7b9d75a2-9f7e-4bde-a3a6-9a5f0e5c2222',
    clientRequestId: 'client-key-1234567890',
    answers: [],
  };

  async function errorsOf(payload: object) {
    return validate(plainToInstance(PublicSurveySubmitDto, payload), {
      whitelist: true,
      forbidNonWhitelisted: true,
    });
  }

  it('accepts the minimal legal payload', async () => {
    expect(await errorsOf(base)).toHaveLength(0);
  });

  it('rejects smuggled fields (case/reward/score never client-writable)', async () => {
    for (const extra of [
      { caseStatus: 'RESOLVED' },
      { reward: { voucherCode: 'X' } },
      { overall: 5 },
      { storeName: 'fake' },
    ]) {
      const errs = await errorsOf({ ...base, ...extra });
      expect(errs.length).toBeGreaterThan(0);
    }
  });

  it('rejects a malformed clientRequestId', async () => {
    const errs = await errorsOf({ ...base, clientRequestId: 'short' });
    expect(errs.length).toBeGreaterThan(0);
  });

  it('accepts contact only through the nested consent shape', async () => {
    expect(
      await errorsOf({
        ...base,
        contact: { name: 'A', phone: '0900000000', consent: true },
      }),
    ).toHaveLength(0);
    expect((await errorsOf({ ...base, contact: { ssn: '123' } })).length).toBeGreaterThan(0);
  });
});

// ── small helpers ───────────────────────────────────────────────────────────

describe('csvField', () => {
  it('quotes, doubles quotes and defuses formula injection', () => {
    expect(csvField('a"b')).toBe('"a""b"');
    expect(csvField('=SUM(A1)')).toBe('"\'=SUM(A1)"');
    expect(csvField(null)).toBe('""');
    expect(csvField(5)).toBe('"5"');
  });
});

describe('normalizeVnPhone', () => {
  it('accepts callable VN numbers (spaces/dots/dashes stripped)', () => {
    expect(normalizeVnPhone('0901 234 567')).toBe('0901234567');
    expect(normalizeVnPhone('+84 90.123-4567')).toBe('+84901234567');
  });

  it('rejects anything staff cannot dial back', () => {
    for (const bad of [null, undefined, '', 'abc', '12345', '090123', 'call me maybe']) {
      expect(normalizeVnPhone(bad)).toBeNull();
    }
  });
});

describe('SurveyReportQueryDto date filters', () => {
  async function errorsOf(payload: object) {
    return validate(plainToInstance(SurveyReportQueryDto, payload));
  }

  it('accepts calendar days only', async () => {
    expect(await errorsOf({ from: '2026-08-01', to: '2026-08-29' })).toHaveLength(0);
  });

  it('rejects datetimes — a timezone-carrying filter would shift VN day reports', async () => {
    expect((await errorsOf({ from: '2026-08-01T00:00:00Z' })).length).toBeGreaterThan(0);
    expect((await errorsOf({ to: '29/08/2026' })).length).toBeGreaterThan(0);
  });
});

describe('vnDayKey', () => {
  it('rolls the day at VN midnight, not UTC midnight', () => {
    // 2026-08-28 18:00 UTC = 2026-08-29 01:00 VN.
    expect(vnDayKey(new Date('2026-08-28T18:00:00Z'))).toBe('2026-08-29');
    expect(vnDayKey(new Date('2026-08-28T16:59:00Z'))).toBe('2026-08-28');
  });
});

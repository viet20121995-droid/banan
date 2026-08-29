/**
 * REAL-PostgreSQL integration tests for the dine-in survey: live store list,
 * submit idempotency under concurrency, reward caps under concurrency,
 * template immutability, PII consent gating and the low-score case + alert
 * outbox. Same fence as internal-races.integration.spec.ts:
 *
 *   1. RUN_DB_INTEGRATION_TESTS=1, otherwise the file is an explicit skip.
 *   2. DATABASE_URL must name a `*_test` database with migrations applied.
 *
 * PowerShell:
 *   $env:RUN_DB_INTEGRATION_TESTS='1'
 *   $env:DATABASE_URL='postgresql://banan:banan@localhost:5432/banan_test?schema=public'
 *   pnpm jest survey.integration
 *
 * Fixtures use IT-SURVEY- / it-survey- prefixes and are deleted in afterAll.
 */
import { BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { PrismaService } from '../../prisma/prisma.service';

import type { PublicSurveySubmitDto } from './dto';
import { SURVEY_TEMPLATE_QUESTIONS } from './survey-template-data';
import { SurveyService } from './survey.service';

jest.setTimeout(60_000);

const ENABLED = process.env.RUN_DB_INTEGRATION_TESTS === '1';
const describeIf = ENABLED ? describe : describe.skip;

const config = {
  get: (key: string) =>
    key === 'SURVEY_ALERT_RECIPIENTS' ? 'it-survey-alerts@test.local' : undefined,
} as unknown as ConfigService;

let seq = 0;
function key(): string {
  return `it-survey-${Date.now()}-${seq++}`;
}

describeIf('dine-in survey (real Postgres)', () => {
  let prisma: PrismaService;
  let survey: SurveyService;
  let storeId: string;
  let templateId: string;
  const qid: Record<string, string> = {};

  beforeAll(async () => {
    prisma = new PrismaService();
    await prisma.$queryRaw`SELECT 1`;
    const [{ current_database: dbName }] = await prisma.$queryRaw<
      { current_database: string }[]
    >`SELECT current_database()`;
    if (!dbName.endsWith('_test')) {
      throw new Error(
        `Refusing to run against "${dbName}" — these tests write fixtures. ` +
          'Point DATABASE_URL at a dedicated *_test database.',
      );
    }
    survey = new SurveyService(prisma, config);

    const store = await prisma.store.create({
      data: {
        name: 'IT-SURVEY store',
        slug: `it-survey-${Date.now()}`,
        address: 'integration-test',
        phone: '0',
        openingHours: {},
      },
    });
    storeId = store.id;

    // Fixture template: the real seed question set, published AS a default —
    // submits only accept the current default (or a just-archived version in
    // its grace window). The seeded banan_test default is left in place and
    // this row is deleted in afterAll.
    const tpl = await prisma.surveyTemplate.create({
      data: {
        name: `IT-SURVEY-tpl-${Date.now()}`,
        version: 1,
        status: 'PUBLISHED',
        isDefault: true,
        publishedAt: new Date(),
        questions: {
          create: SURVEY_TEMPLATE_QUESTIONS.map((q, idx) => ({
            code: q.code,
            type: q.type,
            textVi: q.textVi,
            textEn: q.textEn,
            required: q.required ?? false,
            sortOrder: idx,
            maxLength: q.maxLength ?? null,
            showIfQuestionCode: q.showIfQuestionCode ?? null,
            showIfOp: q.showIfOp ?? null,
            showIfValue: q.showIfValue ?? null,
            ...(q.options
              ? {
                  options: {
                    create: q.options.map((o, oIdx) => ({
                      value: o.value,
                      labelVi: o.labelVi,
                      labelEn: o.labelEn,
                      sortOrder: oIdx,
                    })),
                  },
                }
              : {}),
          })),
        },
      },
      include: { questions: { select: { id: true, code: true } } },
    });
    templateId = tpl.id;
    for (const q of tpl.questions) qid[q.code] = q.id;
  });

  afterAll(async () => {
    if (!prisma) return;
    try {
      // Responses cascade answers, cases (→ alert deliveries) and claims.
      await prisma.surveyResponse.deleteMany({
        where: { clientRequestId: { startsWith: 'it-survey-' } },
      });
      await prisma.surveyRewardCampaign.deleteMany({
        where: { name: { startsWith: 'IT-SURVEY-' } },
      });
      await prisma.surveyTemplate.deleteMany({ where: { name: { startsWith: 'IT-SURVEY-' } } });
      await prisma.store.deleteMany({ where: { slug: { startsWith: 'it-survey-' } } });
    } finally {
      await prisma.$disconnect();
    }
  });

  function dto(overrides: Partial<PublicSurveySubmitDto> = {}): PublicSurveySubmitDto {
    return {
      templateId,
      storeId,
      clientRequestId: key(),
      answers: [{ questionId: qid.overall, numberValue: 5 }],
      ...overrides,
    } as PublicSurveySubmitDto;
  }

  it('a store created in Merchant appears in the public payload on the next load', async () => {
    const fresh = await prisma.store.create({
      data: {
        name: 'IT-SURVEY brand-new branch',
        slug: `it-survey-new-${Date.now()}`,
        address: '123 Test',
        phone: '0',
        openingHours: {},
      },
    });
    const info = await survey.publicInfo();
    expect(info.stores.some((s) => s.id === fresh.id)).toBe(true);
  });

  it('submit against a nonexistent store is rejected', async () => {
    await expect(
      survey.submitPublic(dto({ storeId: '00000000-0000-4000-8000-000000000000' })),
    ).rejects.toThrow(BadRequestException);
  });

  it('overall <= 2 creates exactly ONE case and ONE alert delivery, snapshotting the store name', async () => {
    const res = await survey.submitPublic(
      dto({
        answers: [
          { questionId: qid.overall, numberValue: 1 },
          { questionId: qid.improve, optionValues: ['speed'] },
        ],
      }),
    );
    expect(res.caseId).toBeTruthy();
    const kase = await prisma.surveyCase.findUnique({
      where: { responseId: res.id },
      include: { alerts: true, response: true },
    });
    expect(kase?.status).toBe('NEW');
    expect(kase?.alerts).toHaveLength(1);
    expect(kase?.alerts[0].recipients).toEqual(['it-survey-alerts@test.local']);
    expect(kase?.response.storeName).toBe('IT-SURVEY store');
  });

  it('two SIMULTANEOUS submits with one clientRequestId yield one response/case/reward', async () => {
    const campaign = await prisma.surveyRewardCampaign.create({
      data: {
        name: `IT-SURVEY-idem-${Date.now()}`,
        mode: 'VOUCHER_CODE',
        isEnabled: true,
        probabilityPct: 100,
      },
    });
    try {
      for (let round = 0; round < 3; round++) {
        const payload = dto({
          clientRequestId: key(),
          browserKey: `it-survey-bk-${Date.now()}-${round}`,
          answers: [
            { questionId: qid.overall, numberValue: 1 },
            { questionId: qid.contact_request, numberValue: 1 },
          ],
          contact: { name: 'Khách IT', phone: '0900000000', consent: true },
        });
        const results = await Promise.allSettled([
          survey.submitPublic(payload),
          survey.submitPublic(payload),
        ]);
        const ok = results.filter((r) => r.status === 'fulfilled');
        expect(ok.length).toBe(2); // the loser recovers via the idempotent path
        expect(new Set(ok.map((r) => r.value.id)).size).toBe(1);
        const responses = await prisma.surveyResponse.count({
          where: { clientRequestId: payload.clientRequestId },
        });
        expect(responses).toBe(1);
        const cases = await prisma.surveyCase.count({
          where: { response: { clientRequestId: payload.clientRequestId } },
        });
        expect(cases).toBe(1);
        const alerts = await prisma.surveyAlertDelivery.count({
          where: { case: { response: { clientRequestId: payload.clientRequestId } } },
        });
        expect(alerts).toBe(1);
        const claims = await prisma.surveyRewardClaim.count({
          where: { response: { clientRequestId: payload.clientRequestId } },
        });
        expect(claims).toBeLessThanOrEqual(1);
      }
    } finally {
      await prisma.surveyRewardCampaign.update({
        where: { id: campaign.id },
        data: { isEnabled: false },
      });
    }
  });

  it('concurrent rewards never exceed totalCap; feedback is still saved without a gift', async () => {
    const campaign = await prisma.surveyRewardCampaign.create({
      data: {
        name: `IT-SURVEY-cap-${Date.now()}`,
        mode: 'VOUCHER_CODE',
        isEnabled: true,
        probabilityPct: 100,
        totalCap: 1,
      },
    });
    try {
      const payloads = [0, 1, 2].map((i) =>
        dto({
          clientRequestId: key(),
          browserKey: `it-survey-cap-${Date.now()}-${i}`,
        }),
      );
      const results = await Promise.allSettled(payloads.map((p) => survey.submitPublic(p)));
      expect(results.every((r) => r.status === 'fulfilled')).toBe(true);
      const claims = await prisma.surveyRewardClaim.count({
        where: { campaignId: campaign.id },
      });
      expect(claims).toBe(1);
      const after = await prisma.surveyRewardCampaign.findUnique({
        where: { id: campaign.id },
        select: { issuedCount: true },
      });
      expect(after?.issuedCount).toBe(1); // refusals decremented back
      const responses = await prisma.surveyResponse.count({
        where: { clientRequestId: { in: payloads.map((p) => p.clientRequestId) } },
      });
      expect(responses).toBe(3); // everyone's feedback landed
    } finally {
      await prisma.surveyRewardCampaign.update({
        where: { id: campaign.id },
        data: { isEnabled: false },
      });
    }
  });

  it('one reward per browser per campaign per day — second submit keeps feedback, no gift', async () => {
    const campaign = await prisma.surveyRewardCampaign.create({
      data: {
        name: `IT-SURVEY-daily-${Date.now()}`,
        mode: 'MESSAGE_ONLY',
        isEnabled: true,
        probabilityPct: 100,
      },
    });
    try {
      const browserKey = `it-survey-daily-${Date.now()}`;
      const first = await survey.submitPublic(dto({ browserKey }));
      const second = await survey.submitPublic(dto({ browserKey }));
      expect(first.reward).not.toBeNull();
      expect(second.reward).toBeNull();
      const claims = await prisma.surveyRewardClaim.count({
        where: { campaignId: campaign.id, browserKey },
      });
      expect(claims).toBe(1);
    } finally {
      await prisma.surveyRewardCampaign.update({
        where: { id: campaign.id },
        data: { isEnabled: false },
      });
    }
  });

  it('PII is stored ONLY with consent', async () => {
    const withoutConsent = await survey.submitPublic(
      dto({
        answers: [
          { questionId: qid.overall, numberValue: 1 },
          { questionId: qid.contact_request, numberValue: 0 },
        ],
        contact: { name: 'Không đồng ý', phone: '0911111111', consent: false },
      }),
    );
    const rowA = await prisma.surveyResponse.findUnique({ where: { id: withoutConsent.id } });
    expect(rowA?.contactName).toBeNull();
    expect(rowA?.contactPhone).toBeNull();
    expect(rowA?.contactConsentAt).toBeNull();
    expect(rowA?.contactRequested).toBe(false);

    const withConsent = await survey.submitPublic(
      dto({
        answers: [
          { questionId: qid.overall, numberValue: 2 },
          { questionId: qid.contact_request, numberValue: 1 },
        ],
        contact: { name: 'Đồng ý', phone: '0922222222', consent: true },
      }),
    );
    const rowB = await prisma.surveyResponse.findUnique({ where: { id: withConsent.id } });
    expect(rowB?.contactName).toBe('Đồng ý');
    expect(rowB?.contactPhone).toBe('0922222222');
    expect(rowB?.contactConsentAt).not.toBeNull();
  });

  it('a published template is immutable; responses keep the exact version answered', async () => {
    await expect(
      survey.replaceQuestions(templateId, {
        questions: [
          { code: 'overall', type: 'EMOJI_SCALE', textVi: 'x', textEn: 'x', required: true },
        ],
      }),
    ).rejects.toThrow(BadRequestException);

    // Submitting against the fixture version still records THAT version.
    const res = await survey.submitPublic(dto());
    const row = await prisma.surveyResponse.findUnique({
      where: { id: res.id },
      select: { templateId: true },
    });
    expect(row?.templateId).toBe(templateId);
  });

  it('a reserved question code cannot change type in the editor', async () => {
    const draft = await prisma.surveyTemplate.create({
      data: { name: `IT-SURVEY-reserved-${Date.now()}`, version: 1 },
    });
    await expect(
      survey.replaceQuestions(draft.id, {
        questions: [
          { code: 'overall', type: 'EMOJI_SCALE', textVi: 'x', textEn: 'x', required: true },
          // 'nps' is reserved as NPS — a TEXT question under that code would
          // corrupt the dashboard.
          { code: 'nps', type: 'TEXT', textVi: 'x', textEn: 'x' },
        ],
      }),
    ).rejects.toThrow(BadRequestException);
    // A custom code is free to use any type.
    const ok = await survey.replaceQuestions(draft.id, {
      questions: [
        { code: 'overall', type: 'EMOJI_SCALE', textVi: 'x', textEn: 'x', required: true },
        { code: 'my_custom', type: 'TEXT', textVi: 'x', textEn: 'x' },
      ],
    });
    expect(ok.questions).toHaveLength(2);
  });

  it('an old published-but-no-longer-default template cannot be submitted against', async () => {
    const stale = await prisma.surveyTemplate.create({
      data: {
        name: `IT-SURVEY-stale-${Date.now()}`,
        version: 1,
        status: 'PUBLISHED',
        isDefault: false,
        publishedAt: new Date(),
        questions: {
          create: [
            {
              code: 'overall',
              type: 'EMOJI_SCALE',
              textVi: 'x',
              textEn: 'x',
              required: true,
              sortOrder: 0,
            },
          ],
        },
      },
      include: { questions: { select: { id: true } } },
    });
    await expect(
      survey.submitPublic(
        dto({
          templateId: stale.id,
          answers: [{ questionId: stale.questions[0].id, numberValue: 5 }],
        }),
      ),
    ).rejects.toThrow(BadRequestException);
  });

  it('a just-archived template still accepts an in-flight submit (grace window)', async () => {
    const graced = await prisma.surveyTemplate.create({
      data: {
        name: `IT-SURVEY-grace-${Date.now()}`,
        version: 1,
        status: 'ARCHIVED', // updatedAt = now → inside the grace window
        isDefault: false,
        publishedAt: new Date(),
        questions: {
          create: [
            {
              code: 'overall',
              type: 'EMOJI_SCALE',
              textVi: 'x',
              textEn: 'x',
              required: true,
              sortOrder: 0,
            },
          ],
        },
      },
      include: { questions: { select: { id: true } } },
    });
    const res = await survey.submitPublic(
      dto({
        templateId: graced.id,
        answers: [{ questionId: graced.questions[0].id, numberValue: 5 }],
      }),
    );
    expect(res.id).toBeTruthy();
  });

  it('contact consent without a valid phone is rejected', async () => {
    for (const phone of [undefined, '', 'abc', '12345']) {
      await expect(
        survey.submitPublic(
          dto({
            answers: [
              { questionId: qid.overall, numberValue: 1 },
              { questionId: qid.contact_request, numberValue: 1 },
            ],
            contact: { name: 'Khách', phone, consent: true },
          }),
        ),
      ).rejects.toThrow(BadRequestException);
    }
  });

  it('two SIMULTANEOUS publishes end with exactly ONE published default', async () => {
    const draft = () =>
      prisma.surveyTemplate.create({
        data: {
          name: `IT-SURVEY-pub-${Date.now()}-${seq++}`,
          version: 1,
          questions: {
            create: [
              {
                code: 'overall',
                type: 'EMOJI_SCALE',
                textVi: 'x',
                textEn: 'x',
                required: true,
                sortOrder: 0,
              },
            ],
          },
        },
      });
    // Publishing archives every current default — remember them to restore.
    const prevDefaults = await prisma.surveyTemplate.findMany({
      where: { isDefault: true },
      select: { id: true },
    });
    const [a, b] = await Promise.all([draft(), draft()]);
    try {
      await Promise.allSettled([survey.publishTemplate(a.id), survey.publishTemplate(b.id)]);
      const defaults = await prisma.surveyTemplate.count({
        where: { status: 'PUBLISHED', isDefault: true },
      });
      expect(defaults).toBe(1);
    } finally {
      await prisma.surveyTemplate.deleteMany({ where: { id: { in: [a.id, b.id] } } });
      for (const t of prevDefaults) {
        await prisma.surveyTemplate.update({
          where: { id: t.id },
          data: { status: 'PUBLISHED', isDefault: true },
        });
      }
    }
  });

  it('publish requires the code "overall" specifically, not just any required emoji', async () => {
    const draft = await prisma.surveyTemplate.create({
      data: {
        name: `IT-SURVEY-noover-${Date.now()}`,
        version: 1,
        questions: {
          create: [
            // Required emoji, wrong code — must NOT satisfy the publish gate.
            {
              code: 'mood',
              type: 'EMOJI_SCALE',
              textVi: 'x',
              textEn: 'x',
              required: true,
              sortOrder: 0,
            },
          ],
        },
      },
    });
    await expect(survey.publishTemplate(draft.id)).rejects.toThrow(BadRequestException);
  });

  it('concurrent archive/delete racing a publish can never kill the live default', async () => {
    const prevDefaults = await prisma.surveyTemplate.findMany({
      where: { isDefault: true },
      select: { id: true },
    });
    const draft = (n: string) =>
      prisma.surveyTemplate.create({
        data: {
          name: `IT-SURVEY-race-${n}-${Date.now()}-${seq++}`,
          version: 1,
          questions: {
            create: [
              {
                code: 'overall',
                type: 'EMOJI_SCALE',
                textVi: 'x',
                textEn: 'x',
                required: true,
                sortOrder: 0,
              },
            ],
          },
        },
      });
    const [a, b] = await Promise.all([draft('arch'), draft('del')]);
    try {
      // publish vs archive on the same template — the lock serializes them,
      // so EXACTLY one wins and a live default always remains.
      const archRace = await Promise.allSettled([
        survey.publishTemplate(a.id),
        survey.archiveTemplate(a.id),
      ]);
      expect(archRace.filter((o) => o.status === 'fulfilled')).toHaveLength(1);
      const rowA = await prisma.surveyTemplate.findUnique({ where: { id: a.id } });
      expect(rowA?.status === 'ARCHIVED' && rowA.isDefault).toBe(false);
      expect(
        await prisma.surveyTemplate.count({ where: { status: 'PUBLISHED', isDefault: true } }),
      ).toBeGreaterThanOrEqual(1);
      // publish vs delete on the same template — same invariant.
      const delRace = await Promise.allSettled([
        survey.publishTemplate(b.id),
        survey.deleteTemplate(b.id),
      ]);
      expect(delRace.filter((o) => o.status === 'fulfilled')).toHaveLength(1);
      expect(
        await prisma.surveyTemplate.count({ where: { status: 'PUBLISHED', isDefault: true } }),
      ).toBeGreaterThanOrEqual(1);
    } finally {
      await prisma.surveyTemplate.deleteMany({ where: { id: { in: [a.id, b.id] } } });
      for (const t of prevDefaults) {
        await prisma.surveyTemplate.update({
          where: { id: t.id },
          data: { status: 'PUBLISHED', isDefault: true },
        });
      }
    }
  });

  it('two admins enabling campaigns SIMULTANEOUSLY end with exactly one enabled', async () => {
    const stamp = Date.now();
    const results = await Promise.allSettled([
      survey.createCampaign({ name: `IT-SURVEY-racecamp-A-${stamp}`, isEnabled: true }),
      survey.createCampaign({ name: `IT-SURVEY-racecamp-B-${stamp}`, isEnabled: true }),
    ]);
    try {
      expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
      const enabled = await prisma.surveyRewardCampaign.count({ where: { isEnabled: true } });
      expect(enabled).toBe(1);
    } finally {
      await prisma.surveyRewardCampaign.updateMany({
        where: { name: { startsWith: 'IT-SURVEY-racecamp-' } },
        data: { isEnabled: false },
      });
    }
  });

  it('case resolve state stays consistent across status flips', async () => {
    const res = await survey.submitPublic(
      dto({ answers: [{ questionId: qid.overall, numberValue: 1 }] }),
    );
    const kase = await prisma.surveyCase.findUniqueOrThrow({ where: { responseId: res.id } });

    const resolved = await survey.updateCase(kase.id, { status: 'RESOLVED' }, 'it-admin-1');
    expect(resolved.resolvedAt).not.toBeNull();

    // Re-resolving keeps the FIRST resolver/time.
    const again = await survey.updateCase(kase.id, { status: 'RESOLVED' }, 'it-admin-2');
    expect(again.resolvedAt).toBe(resolved.resolvedAt);
    const row = await prisma.surveyCase.findUniqueOrThrow({ where: { id: kase.id } });
    expect(row.resolvedById).toBe('it-admin-1');

    // Reopening clears both — no resolve stamps on an unresolved case.
    const reopened = await survey.updateCase(kase.id, { status: 'IN_PROGRESS' }, 'it-admin-1');
    expect(reopened.resolvedAt).toBeNull();
    const row2 = await prisma.surveyCase.findUniqueOrThrow({ where: { id: kase.id } });
    expect(row2.resolvedById).toBeNull();
  });

  it('at most one reward campaign can be enabled; window and null-clear are enforced', async () => {
    const list = await survey.createCampaign({
      name: `IT-SURVEY-only-${Date.now()}`,
      isEnabled: true,
      startsAt: '2026-01-01T00:00:00Z',
    });
    const created = list.find((c) => c.name.startsWith('IT-SURVEY-only-'))!;
    try {
      await expect(
        survey.createCampaign({ name: `IT-SURVEY-second-${Date.now()}`, isEnabled: true }),
      ).rejects.toThrow(BadRequestException);
      await expect(
        survey.updateCampaign(created.id, { endsAt: '2025-01-01T00:00:00Z' } as never),
      ).rejects.toThrow(BadRequestException);
      // Explicit null clears the stored start date.
      const after = await survey.updateCampaign(created.id, { startsAt: null } as never);
      expect(after.find((c) => c.id === created.id)?.startsAt).toBeNull();
    } finally {
      await survey.updateCampaign(created.id, { isEnabled: false } as never);
    }
  });

  it('conditional rules are enforced at the DB boundary too', async () => {
    await expect(
      survey.submitPublic(
        dto({
          answers: [
            { questionId: qid.overall, numberValue: 5 },
            { questionId: qid.improve, optionValues: ['taste'] },
          ],
        }),
      ),
    ).rejects.toThrow(BadRequestException);
  });
});

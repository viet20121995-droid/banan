import { randomInt } from 'node:crypto';

import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { surveyAlertRecipients, surveyCaseSlaHours } from '../internal-config';

import type {
  CreateSurveyRewardDto,
  CreateSurveyTemplateDto,
  PublicSurveySubmitDto,
  RedeemSurveyRewardDto,
  ReplaceSurveyQuestionsDto,
  SurveyCasesQueryDto,
  SurveyClaimsQueryDto,
  SurveyReportQueryDto,
  SurveyResponsesQueryDto,
  UpdateSurveyCaseDto,
  UpdateSurveyRewardDto,
  UpdateSurveyTemplateDto,
} from './dto';
import { validateSurveyAnswers } from './survey-validation';

/** yyyy-MM-dd in Asia/Ho_Chi_Minh — the reward day boundary + trend bucket. */
export function vnDayKey(d: Date = new Date()): string {
  return d.toLocaleDateString('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' });
}

/** ISO Monday of the VN day — the week trend bucket. */
function vnWeekKey(d: Date): string {
  const day = vnDayKey(d); // yyyy-MM-dd
  const utcNoon = new Date(`${day}T12:00:00Z`); // DoW is TZ-safe at noon
  const dow = (utcNoon.getUTCDay() + 6) % 7; // 0 = Monday
  utcNoon.setUTCDate(utcNoon.getUTCDate() - dow);
  return utcNoon.toISOString().slice(0, 10);
}

function freshVoucherCode(): string {
  // Unambiguous alphabet (no 0/O/1/I/L) — staff read these aloud.
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 8; i++) code += chars[randomInt(chars.length)];
  return `BAN-${code.slice(0, 4)}-${code.slice(4)}`;
}

/** CSV field: quoted, quotes doubled, formula-injection defused. */
export function csvField(v: string | number | null | undefined): string {
  if (v == null) return '""';
  let s = String(v);
  if (/^[=+\-@]/.test(s)) s = `'${s}`;
  return `"${s.replace(/"/g, '""')}"`;
}

const QUESTION_VIEW = {
  orderBy: { sortOrder: 'asc' as const },
  include: { options: { orderBy: { sortOrder: 'asc' as const } } },
};

/**
 * Codes the dashboard, CSV and case pipeline key on. The editor may reword,
 * reorder or drop them, but a reserved code must keep its type — otherwise a
 * renamed "nps" TEXT question would silently corrupt every report. Custom
 * codes are free-form and surface via the dynamic CSV columns.
 */
export const RESERVED_QUESTION_TYPES: Record<string, string> = {
  overall: 'EMOJI_SCALE',
  food_drink: 'RATING',
  service_attitude: 'RATING',
  service_speed: 'RATING',
  space_clean: 'RATING',
  improve: 'MULTI_CHOICE',
  praise: 'MULTI_CHOICE',
  nps: 'NPS',
  comment: 'TEXT',
  contact_request: 'YES_NO',
};

/** Fixed CSV columns — answers to any other code get a dynamic column each. */
const FIXED_CSV_CODES = new Set(Object.keys(RESERVED_QUESTION_TYPES));

/** VN phone the staff can actually call back: 0… or +84…, 9–11 digits. */
export function normalizeVnPhone(raw: string | null | undefined): string | null {
  const digits = (raw ?? '').replace(/[\s.()-]/g, '');
  return /^(?:\+84|0)\d{8,10}$/.test(digits) ? digits : null;
}

/** Start of a VN calendar day (input `yyyy-MM-dd`). */
function vnDayStart(day: string): Date {
  return new Date(`${day}T00:00:00+07:00`);
}

/** A guest may finish a form loaded just before a new version went live. */
const ARCHIVED_TEMPLATE_GRACE_MS = 2 * 3_600_000;

@Injectable()
export class SurveyService {
  private readonly logger = new Logger(SurveyService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  // ── public ────────────────────────────────────────────────────────────────

  /**
   * Everything the public /survey page needs in one call: the published
   * default template, the LIVE store list (a branch added in Merchant shows
   * up on the next load — nothing is hardcoded or cached in a bundle) and
   * the reward teaser (name/description only — caps and odds stay private).
   */
  async publicInfo() {
    const [template, stores, campaign] = await Promise.all([
      this.prisma.surveyTemplate.findFirst({
        where: { status: 'PUBLISHED', isDefault: true },
        include: { questions: QUESTION_VIEW },
      }),
      this.prisma.store.findMany({
        select: { id: true, name: true, address: true },
        orderBy: { name: 'asc' },
      }),
      this.activeCampaign(),
    ]);
    return {
      template: template ? this.templateView(template) : null,
      stores,
      reward: campaign ? { name: campaign.name, description: campaign.description } : null,
    };
  }

  /**
   * Public submission. One transaction creates response (+answers), the
   * low-score case, its alert outbox row and the reward claim — so a retry
   * with the same `clientRequestId` returns the SAME response and reward,
   * and a crash can never leave half a submission.
   *
   * Returns `{ caseId }` alongside the guest payload so the controller can
   * fire the alert dispatch AFTER the commit (never inside the tx).
   */
  async submitPublic(dto: PublicSurveySubmitDto) {
    // Idempotent retry — the earlier submit already did everything.
    const prior = await this.prisma.surveyResponse.findUnique({
      where: { clientRequestId: dto.clientRequestId },
      select: { id: true },
    });
    if (prior) return { ...(await this.submitResult(prior.id)), caseId: null };

    const template = await this.prisma.surveyTemplate.findUnique({
      where: { id: dto.templateId },
      include: { questions: QUESTION_VIEW },
    });
    // Only the CURRENT published default — plus a short grace for a version
    // archived while the guest was mid-form (updatedAt ≈ archive time). An
    // old template id can't be replayed forever to dodge new required
    // questions; the response still records the exact version answered.
    const templateAccepted =
      template != null &&
      ((template.status === 'PUBLISHED' && template.isDefault) ||
        (template.status === 'ARCHIVED' &&
          template.publishedAt != null &&
          Date.now() - template.updatedAt.getTime() < ARCHIVED_TEMPLATE_GRACE_MS));
    if (!template || !templateAccepted) {
      throw new BadRequestException({
        code: 'SURVEY_TEMPLATE_INVALID',
        message: 'Mẫu khảo sát không hợp lệ — tải lại trang.',
      });
    }
    const store = await this.prisma.store.findUnique({
      where: { id: dto.storeId },
      select: { id: true, name: true },
    });
    if (!store) {
      throw new BadRequestException({
        code: 'SURVEY_STORE_NOT_FOUND',
        message: 'Chi nhánh không hợp lệ — tải lại trang.',
      });
    }

    const { clean, overall } = validateSurveyAnswers(template.questions, dto.answers);
    const comment = clean.find((c) => c.questionCode === 'comment')?.textValue ?? null;
    const nps = clean.find((c) => c.questionCode === 'nps')?.numberValue ?? null;

    // PII gate: stored ONLY with explicit consent AND a low score (the only
    // flow that ever shows the contact form). Anything else is dropped.
    const wantsContact = overall != null && overall <= 2 && dto.contact?.consent === true;
    const contactName = wantsContact ? dto.contact?.name?.trim() || null : null;
    const contactPhone = wantsContact ? normalizeVnPhone(dto.contact?.phone) : null;
    // Consent without a callable number would create a case staff can't act
    // on — a "please contact me" MUST carry a valid phone.
    if (wantsContact && !contactPhone) {
      throw new BadRequestException({
        code: 'SURVEY_CONTACT_PHONE_INVALID',
        message: 'Cần số điện thoại hợp lệ để Banan liên hệ lại.',
      });
    }

    const recipients = surveyAlertRecipients(this.config);
    const campaign = await this.activeCampaign();
    const rewardEligible =
      campaign != null && !!dto.browserKey && randomInt(100) < campaign.probabilityPct;
    const dayKey = vnDayKey();

    let caseId: string | null = null;
    try {
      await this.prisma.$transaction(async (tx) => {
        const response = await tx.surveyResponse.create({
          data: {
            templateId: template.id,
            storeId: store.id,
            storeName: store.name,
            overall,
            nps,
            comment,
            locale: dto.locale === 'en' ? 'en' : 'vi',
            contactRequested: wantsContact,
            contactName,
            contactPhone,
            contactConsentAt: wantsContact ? new Date() : null,
            clientRequestId: dto.clientRequestId,
            browserKey: dto.browserKey ?? null,
            answers: {
              create: clean.map((c) => ({
                questionId: c.questionId,
                questionCode: c.questionCode,
                numberValue: c.numberValue,
                textValue: c.textValue,
                optionValues: c.optionValues,
              })),
            },
          },
          select: { id: true, createdAt: true },
        });

        if (overall != null && overall <= 2) {
          const kase = await tx.surveyCase.create({
            data: { responseId: response.id },
            select: { id: true },
          });
          caseId = kase.id;
          if (recipients.length > 0) {
            await tx.surveyAlertDelivery.create({
              data: {
                caseId: kase.id,
                recipients,
                snapshot: {
                  storeName: store.name,
                  overall,
                  comment,
                  contact: wantsContact ? { name: contactName, phone: contactPhone } : null,
                  submittedAt: response.createdAt.toISOString(),
                },
              },
            });
          } else {
            this.logger.warn(
              'SURVEY_ALERT_RECIPIENTS unset — low-score case created without an alert email',
            );
          }
        }

        if (rewardEligible && campaign) {
          await this.tryGrantReward(tx, campaign, response.id, dto.browserKey!, dayKey);
        }
      });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        // Two SIMULTANEOUS submits with the same key — the other one won.
        const winner = await this.prisma.surveyResponse.findUnique({
          where: { clientRequestId: dto.clientRequestId },
          select: { id: true },
        });
        if (winner) return { ...(await this.submitResult(winner.id)), caseId: null };
      }
      throw e;
    }

    const created = await this.prisma.surveyResponse.findUnique({
      where: { clientRequestId: dto.clientRequestId },
      select: { id: true },
    });
    return { ...(await this.submitResult(created!.id)), caseId };
  }

  /** Reward campaign currently live for guests, or null. */
  private activeCampaign() {
    const now = new Date();
    return this.prisma.surveyRewardCampaign.findFirst({
      where: {
        isEnabled: true,
        mode: { not: 'NONE' },
        OR: [{ startsAt: null }, { startsAt: { lte: now } }],
        AND: [{ OR: [{ endsAt: null }, { endsAt: { gte: now } }] }],
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Reward grant inside the submit tx. The conditional UPDATE both enforces
   * the total cap and takes the campaign row lock, serializing concurrent
   * claims so the daily-cap count and the per-browser pre-check are race
   * free. Every refusal path decrements the counter back — a refusal must
   * never burn cap, and must never abort the tx (feedback still counts).
   */
  private async tryGrantReward(
    tx: Prisma.TransactionClient,
    campaign: {
      id: string;
      mode: string;
      dailyCap: number | null;
      expiryDays: number;
    },
    responseId: string,
    browserKey: string,
    dayKey: string,
  ): Promise<void> {
    const locked = await tx.$executeRaw`
      UPDATE "SurveyRewardCampaign"
      SET "issuedCount" = "issuedCount" + 1
      WHERE "id" = ${campaign.id}
        AND ("totalCap" IS NULL OR "issuedCount" < "totalCap")`;
    if (locked === 0) return; // total cap reached
    const undo = () =>
      tx.surveyRewardCampaign.update({
        where: { id: campaign.id },
        data: { issuedCount: { decrement: 1 } },
      });

    // One reward per browser per campaign per day (pre-checked under the row
    // lock; the unique constraint stays as the hard DB guard).
    const dup = await tx.surveyRewardClaim.findFirst({
      where: { campaignId: campaign.id, browserKey, dayKey },
      select: { id: true },
    });
    if (dup) {
      await undo();
      return;
    }
    if (campaign.dailyCap != null) {
      const today = await tx.surveyRewardClaim.count({
        where: { campaignId: campaign.id, dayKey },
      });
      if (today >= campaign.dailyCap) {
        await undo();
        return;
      }
    }
    await tx.surveyRewardClaim.create({
      data: {
        campaignId: campaign.id,
        responseId,
        browserKey,
        dayKey,
        voucherCode: campaign.mode === 'VOUCHER_CODE' ? freshVoucherCode() : null,
        expiresAt: new Date(Date.now() + campaign.expiryDays * 86_400_000),
      },
    });
  }

  /** The guest-facing submit payload — same shape on first submit and retry. */
  private async submitResult(responseId: string) {
    const row = await this.prisma.surveyResponse.findUnique({
      where: { id: responseId },
      select: {
        id: true,
        rewardClaim: {
          select: {
            voucherCode: true,
            expiresAt: true,
            campaign: {
              select: { mode: true, name: true, description: true, instructions: true },
            },
          },
        },
      },
    });
    const claim = row?.rewardClaim;
    return {
      id: row!.id,
      reward: claim
        ? {
            mode: claim.campaign.mode,
            name: claim.campaign.name,
            description: claim.campaign.description,
            instructions: claim.campaign.instructions,
            voucherCode: claim.voucherCode,
            expiresAt: claim.expiresAt?.toISOString() ?? null,
          }
        : null,
    };
  }

  // ── admin: reports ────────────────────────────────────────────────────────

  private responseWhere(q: SurveyReportQueryDto): Prisma.SurveyResponseWhereInput {
    const slaCutoff = new Date(Date.now() - surveyCaseSlaHours(this.config) * 3_600_000);
    return {
      // Date-only filters, anchored to VN calendar days: [from 00:00 VN,
      // day-after-to 00:00 VN) — a "ngày 29" report means VN's Aug 29, not
      // the server timezone's.
      ...(q.from || q.to
        ? {
            createdAt: {
              ...(q.from ? { gte: vnDayStart(q.from) } : {}),
              ...(q.to ? { lt: new Date(vnDayStart(q.to).getTime() + 86_400_000) } : {}),
            },
          }
        : {}),
      ...(q.storeId ? { storeId: q.storeId } : {}),
      ...(q.templateId ? { templateId: q.templateId } : {}),
      ...(q.overall != null ? { overall: q.overall } : {}),
      ...(q.caseStatus
        ? {
            case:
              q.caseStatus === 'OVERDUE'
                ? { is: { status: { not: 'RESOLVED' }, createdAt: { lt: slaCutoff } } }
                : { is: { status: q.caseStatus as never } },
          }
        : {}),
    };
  }

  /**
   * Dashboard aggregates. Computed in one JS pass over the filtered window —
   * a 4-branch bakery's volume never needs SQL rollups.
   * ponytail: JS aggregation; move to SQL GROUP BYs if volume grows.
   */
  async reportSummary(q: SurveyReportQueryDto) {
    const where = this.responseWhere(q);
    const slaCutoff = new Date(Date.now() - surveyCaseSlaHours(this.config) * 3_600_000);
    const [rows, answers, openCases, overdueCases, comments] = await Promise.all([
      this.prisma.surveyResponse.findMany({
        where,
        select: {
          createdAt: true,
          overall: true,
          nps: true,
          storeId: true,
          storeName: true,
        },
      }),
      this.prisma.surveyAnswer.findMany({
        where: {
          response: where,
          OR: [{ numberValue: { not: null } }, { optionValues: { isEmpty: false } }],
        },
        select: {
          questionCode: true,
          numberValue: true,
          optionValues: true,
          question: { select: { type: true, textVi: true } },
        },
      }),
      this.prisma.surveyCase.count({
        where: { status: { not: 'RESOLVED' }, response: where },
      }),
      this.prisma.surveyCase.count({
        where: { status: { not: 'RESOLVED' }, createdAt: { lt: slaCutoff }, response: where },
      }),
      this.prisma.surveyResponse.findMany({
        where: { ...where, comment: { not: null } },
        orderBy: { createdAt: 'desc' },
        take: 10,
        select: { id: true, comment: true, storeName: true, overall: true, createdAt: true },
      }),
    ]);

    let overallSum = 0;
    let overallCount = 0;
    let high = 0;
    let low = 0;
    let promoters = 0;
    let detractors = 0;
    let npsCount = 0;
    const trend = new Map<string, { count: number; sum: number; n: number }>();
    const perStore = new Map<
      string,
      { storeName: string; count: number; sum: number; n: number; low: number }
    >();
    const bucketOf = q.bucket === 'week' ? vnWeekKey : vnDayKey;
    for (const r of rows) {
      if (r.overall != null) {
        overallSum += r.overall;
        overallCount++;
        if (r.overall >= 4) high++;
        if (r.overall <= 2) low++;
      }
      if (r.nps != null) {
        npsCount++;
        if (r.nps >= 9) promoters++;
        if (r.nps <= 6) detractors++;
      }
      const key = bucketOf(r.createdAt);
      const t = trend.get(key) ?? { count: 0, sum: 0, n: 0 };
      t.count++;
      if (r.overall != null) {
        t.sum += r.overall;
        t.n++;
      }
      trend.set(key, t);
      const s = perStore.get(r.storeId) ?? {
        storeName: r.storeName,
        count: 0,
        sum: 0,
        n: 0,
        low: 0,
      };
      s.count++;
      s.storeName = r.storeName; // latest snapshot wins as the display name
      if (r.overall != null) {
        s.sum += r.overall;
        s.n++;
        if (r.overall <= 2) s.low++;
      }
      perStore.set(r.storeId, s);
    }

    const categories = new Map<string, { label: string; sum: number; n: number }>();
    const issueCounts = new Map<string, number>();
    const praiseCounts = new Map<string, number>();
    for (const a of answers) {
      if (a.question.type === 'RATING' && a.numberValue != null) {
        const c = categories.get(a.questionCode) ?? {
          label: a.question.textVi,
          sum: 0,
          n: 0,
        };
        c.sum += a.numberValue;
        c.n++;
        categories.set(a.questionCode, c);
      }
      if (a.question.type === 'MULTI_CHOICE' || a.question.type === 'SINGLE_CHOICE') {
        // Only the two reserved codes feed these widgets — a custom choice
        // question must not be misfiled as an "issue"; it lives in the CSV.
        const target =
          a.questionCode === 'praise'
            ? praiseCounts
            : a.questionCode === 'improve'
              ? issueCounts
              : null;
        if (target) for (const v of a.optionValues) target.set(v, (target.get(v) ?? 0) + 1);
      }
    }
    const optionLabels = await this.optionLabels();
    const topOf = (m: Map<string, number>) =>
      [...m.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 10)
        .map(([value, count]) => ({ value, label: optionLabels.get(value) ?? value, count }));

    return {
      total: rows.length,
      avgOverall: overallCount ? Math.round((overallSum / overallCount) * 100) / 100 : null,
      pctHigh: overallCount ? Math.round((high / overallCount) * 100) : null,
      pctLow: overallCount ? Math.round((low / overallCount) * 100) : null,
      nps: npsCount ? Math.round(((promoters - detractors) / npsCount) * 100) : null,
      npsCount,
      openCases,
      overdueCases,
      trend: [...trend.entries()]
        .sort((a, b) => a[0].localeCompare(b[0]))
        .map(([bucket, t]) => ({
          bucket,
          count: t.count,
          avgOverall: t.n ? Math.round((t.sum / t.n) * 100) / 100 : null,
        })),
      stores: [...perStore.entries()]
        .map(([storeId, s]) => ({
          storeId,
          storeName: s.storeName,
          count: s.count,
          avgOverall: s.n ? Math.round((s.sum / s.n) * 100) / 100 : null,
          lowCount: s.low,
        }))
        .sort((a, b) => a.storeName.localeCompare(b.storeName)),
      categories: [...categories.entries()].map(([code, c]) => ({
        code,
        label: c.label,
        avg: c.n ? Math.round((c.sum / c.n) * 100) / 100 : null,
        count: c.n,
      })),
      topIssues: topOf(issueCounts),
      topPraise: topOf(praiseCounts),
      recentComments: comments.map((c) => ({
        id: c.id,
        comment: c.comment,
        storeName: c.storeName,
        overall: c.overall,
        createdAt: c.createdAt.toISOString(),
      })),
    };
  }

  /** value → labelVi across improve/praise questions (latest template wins). */
  private async optionLabels(): Promise<Map<string, string>> {
    const options = await this.prisma.surveyOption.findMany({
      where: { question: { code: { in: ['improve', 'praise'] } } },
      select: {
        value: true,
        labelVi: true,
        question: { select: { template: { select: { version: true } } } },
      },
      orderBy: { question: { template: { version: 'asc' } } },
    });
    const map = new Map<string, string>();
    for (const o of options) map.set(o.value, o.labelVi);
    return map;
  }

  async listResponses(q: SurveyResponsesQueryDto) {
    const where = this.responseWhere(q);
    const page = q.page ?? 1;
    const perPage = q.perPage ?? 30;
    const slaCutoff = new Date(Date.now() - surveyCaseSlaHours(this.config) * 3_600_000);
    const rows = await this.prisma.surveyResponse.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * perPage,
      take: perPage,
      include: {
        case: { select: { id: true, status: true, createdAt: true } },
        template: { select: { version: true } },
      },
    });
    return rows.map((r) => ({
      id: r.id,
      createdAt: r.createdAt.toISOString(),
      storeName: r.storeName,
      overall: r.overall,
      nps: r.nps,
      comment: r.comment,
      locale: r.locale,
      templateVersion: r.template.version,
      contactRequested: r.contactRequested,
      caseStatus: r.case
        ? r.case.status !== 'RESOLVED' && r.case.createdAt < slaCutoff
          ? 'OVERDUE'
          : r.case.status
        : null,
    }));
  }

  /** UTF-8 CSV (BOM'd so Excel decodes it) of the filtered responses. */
  async exportCsv(q: SurveyReportQueryDto): Promise<string> {
    const rows = await this.prisma.surveyResponse.findMany({
      where: this.responseWhere(q),
      orderBy: { createdAt: 'asc' },
      include: {
        answers: {
          select: { questionCode: true, numberValue: true, textValue: true, optionValues: true },
        },
        case: { select: { status: true } },
        template: { select: { version: true } },
      },
    });
    const header = [
      'id',
      'thoi_gian',
      'chi_nhanh',
      'phien_ban_mau',
      'tong_the',
      'banh_do_uong',
      'thai_do_phuc_vu',
      'toc_do_phuc_vu',
      'khong_gian_ve_sinh',
      'nps',
      'can_cai_thien',
      'yeu_thich',
      'gop_y',
      'muon_lien_he',
      'ten_khach',
      'sdt_khach',
      'case_status',
    ];
    // Custom editor questions get one dynamic column each, so a modified
    // template never loses data in the export.
    const extraCodes = [...new Set(rows.flatMap((r) => r.answers.map((a) => a.questionCode)))]
      .filter((c) => !FIXED_CSV_CODES.has(c))
      .sort();
    const lines = [[...header, ...extraCodes].map(csvField).join(',')];
    for (const r of rows) {
      const by = new Map(r.answers.map((a) => [a.questionCode, a]));
      const num = (code: string) => by.get(code)?.numberValue ?? null;
      const opts = (code: string) => by.get(code)?.optionValues.join('; ') ?? null;
      const any = (code: string) => {
        const a = by.get(code);
        if (!a) return null;
        return (
          a.numberValue ?? a.textValue ?? (a.optionValues.length ? a.optionValues.join('; ') : null)
        );
      };
      lines.push(
        [
          csvField(r.id),
          csvField(r.createdAt.toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })),
          csvField(r.storeName),
          csvField(r.template.version),
          csvField(r.overall),
          csvField(num('food_drink')),
          csvField(num('service_attitude')),
          csvField(num('service_speed')),
          csvField(num('space_clean')),
          csvField(r.nps),
          csvField(opts('improve')),
          csvField(opts('praise')),
          csvField(r.comment),
          csvField(r.contactRequested ? 'Y' : 'N'),
          csvField(r.contactName),
          csvField(r.contactPhone),
          csvField(r.case?.status ?? null),
          ...extraCodes.map((c) => csvField(any(c))),
        ].join(','),
      );
    }
    return `﻿${lines.join('\r\n')}`;
  }

  // ── admin: cases ──────────────────────────────────────────────────────────

  private caseView(
    c: {
      id: string;
      status: string;
      assigneeName: string | null;
      note: string | null;
      resolvedAt: Date | null;
      createdAt: Date;
      updatedAt: Date;
      response: {
        id: string;
        storeName: string;
        overall: number | null;
        nps: number | null;
        comment: string | null;
        createdAt: Date;
        contactRequested: boolean;
        contactName: string | null;
        contactPhone: string | null;
        contactConsentAt: Date | null;
      };
    },
    slaCutoff: Date,
  ) {
    return {
      id: c.id,
      status: c.status,
      overdue: c.status !== 'RESOLVED' && c.createdAt < slaCutoff,
      assigneeName: c.assigneeName,
      note: c.note,
      resolvedAt: c.resolvedAt?.toISOString() ?? null,
      createdAt: c.createdAt.toISOString(),
      updatedAt: c.updatedAt.toISOString(),
      response: {
        id: c.response.id,
        storeName: c.response.storeName,
        overall: c.response.overall,
        nps: c.response.nps,
        comment: c.response.comment,
        createdAt: c.response.createdAt.toISOString(),
        // Guest contact ONLY with recorded consent — never otherwise.
        contact:
          c.response.contactConsentAt != null
            ? { name: c.response.contactName, phone: c.response.contactPhone }
            : null,
      },
    };
  }

  async listCases(q: SurveyCasesQueryDto) {
    const slaCutoff = new Date(Date.now() - surveyCaseSlaHours(this.config) * 3_600_000);
    const where: Prisma.SurveyCaseWhereInput = {
      ...(q.status
        ? q.status === 'OVERDUE'
          ? { status: { not: 'RESOLVED' }, createdAt: { lt: slaCutoff } }
          : { status: q.status as never }
        : {}),
      ...(q.storeId ? { response: { storeId: q.storeId } } : {}),
    };
    const page = q.page ?? 1;
    const perPage = q.perPage ?? 50;
    const rows = await this.prisma.surveyCase.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * perPage,
      take: perPage,
      include: { response: true },
    });
    return rows.map((c) => this.caseView(c, slaCutoff));
  }

  async updateCase(id: string, dto: UpdateSurveyCaseDto, actorId: string) {
    const existing = await this.prisma.surveyCase.findUnique({ where: { id } });
    if (!existing) {
      throw new NotFoundException({
        code: 'SURVEY_CASE_NOT_FOUND',
        message: 'Không tìm thấy case.',
      });
    }
    // resolvedAt/resolvedById are derived from the NEW status in the SAME
    // write — never from a pre-read snapshot, so two concurrent updates can't
    // leave resolve timestamps on an unresolved case (or vice versa).
    const common = {
      ...(dto.assigneeName !== undefined ? { assigneeName: dto.assigneeName.trim() || null } : {}),
      ...(dto.note !== undefined ? { note: dto.note.trim() || null } : {}),
    };
    if (dto.status === 'RESOLVED') {
      const first = await this.prisma.surveyCase.updateMany({
        where: { id, status: { not: 'RESOLVED' } },
        data: { ...common, status: 'RESOLVED', resolvedAt: new Date(), resolvedById: actorId },
      });
      if (first.count === 0) {
        // Already resolved — keep the original resolver/time, apply the rest.
        await this.prisma.surveyCase.update({ where: { id }, data: common });
      }
    } else if (dto.status) {
      await this.prisma.surveyCase.update({
        where: { id },
        data: { ...common, status: dto.status as never, resolvedAt: null, resolvedById: null },
      });
    } else {
      await this.prisma.surveyCase.update({ where: { id }, data: common });
    }
    const updated = await this.prisma.surveyCase.findUniqueOrThrow({
      where: { id },
      include: { response: true },
    });
    const slaCutoff = new Date(Date.now() - surveyCaseSlaHours(this.config) * 3_600_000);
    return this.caseView(updated, slaCutoff);
  }

  // ── admin: templates ──────────────────────────────────────────────────────

  private templateView(t: {
    id: string;
    name: string;
    version: number;
    status?: string;
    isDefault?: boolean;
    publishedAt?: Date | null;
    questions: {
      id: string;
      code: string;
      type: string;
      textVi: string;
      textEn: string;
      required: boolean;
      sortOrder: number;
      maxLength: number | null;
      showIfQuestionCode: string | null;
      showIfOp: string | null;
      showIfValue: number | null;
      options: { id: string; value: string; labelVi: string; labelEn: string; sortOrder: number }[];
    }[];
  }) {
    return {
      id: t.id,
      name: t.name,
      version: t.version,
      ...(t.status ? { status: t.status } : {}),
      ...(t.isDefault !== undefined ? { isDefault: t.isDefault } : {}),
      ...(t.publishedAt !== undefined ? { publishedAt: t.publishedAt?.toISOString() ?? null } : {}),
      questions: t.questions.map((qq) => ({
        id: qq.id,
        code: qq.code,
        type: qq.type,
        textVi: qq.textVi,
        textEn: qq.textEn,
        required: qq.required,
        sortOrder: qq.sortOrder,
        maxLength: qq.maxLength,
        showIfQuestionCode: qq.showIfQuestionCode,
        showIfOp: qq.showIfOp,
        showIfValue: qq.showIfValue,
        options: qq.options,
      })),
    };
  }

  async listTemplates() {
    const rows = await this.prisma.surveyTemplate.findMany({
      orderBy: [{ name: 'asc' }, { version: 'desc' }],
      include: { _count: { select: { responses: true, questions: true } } },
    });
    return rows.map((t) => ({
      id: t.id,
      name: t.name,
      version: t.version,
      status: t.status,
      isDefault: t.isDefault,
      publishedAt: t.publishedAt?.toISOString() ?? null,
      questionCount: t._count.questions,
      responseCount: t._count.responses,
    }));
  }

  async templateDetail(id: string) {
    const t = await this.prisma.surveyTemplate.findUnique({
      where: { id },
      include: { questions: QUESTION_VIEW },
    });
    if (!t) {
      throw new NotFoundException({
        code: 'SURVEY_TEMPLATE_NOT_FOUND',
        message: 'Không tìm thấy mẫu khảo sát.',
      });
    }
    return this.templateView(t);
  }

  /** New DRAFT — blank, or a clone of any existing version (the ONLY way to
   *  "edit" a published version). */
  async createTemplate(dto: CreateSurveyTemplateDto, actorId: string) {
    const source = dto.cloneFromId
      ? await this.prisma.surveyTemplate.findUnique({
          where: { id: dto.cloneFromId },
          include: { questions: QUESTION_VIEW },
        })
      : null;
    if (dto.cloneFromId && !source) {
      throw new NotFoundException({
        code: 'SURVEY_TEMPLATE_NOT_FOUND',
        message: 'Không tìm thấy mẫu nguồn.',
      });
    }
    const name = dto.name?.trim() || source?.name;
    if (!name) {
      throw new BadRequestException({
        code: 'SURVEY_TEMPLATE_NAME_REQUIRED',
        message: 'Cần tên mẫu khảo sát.',
      });
    }
    const latest = await this.prisma.surveyTemplate.findFirst({
      where: { name },
      orderBy: { version: 'desc' },
      select: { version: true },
    });
    const created = await this.prisma.surveyTemplate.create({
      data: {
        name,
        version: (latest?.version ?? 0) + 1,
        createdById: actorId,
        ...(source
          ? {
              questions: {
                create: source.questions.map((qq) => ({
                  code: qq.code,
                  type: qq.type,
                  textVi: qq.textVi,
                  textEn: qq.textEn,
                  required: qq.required,
                  sortOrder: qq.sortOrder,
                  maxLength: qq.maxLength,
                  showIfQuestionCode: qq.showIfQuestionCode,
                  showIfOp: qq.showIfOp,
                  showIfValue: qq.showIfValue,
                  options: {
                    create: qq.options.map((o) => ({
                      value: o.value,
                      labelVi: o.labelVi,
                      labelEn: o.labelEn,
                      sortOrder: o.sortOrder,
                    })),
                  },
                })),
              },
            }
          : {}),
      },
      select: { id: true },
    });
    return this.templateDetail(created.id);
  }

  /**
   * One advisory xact-lock serializes every publish/question-write, so two
   * concurrent publishes can never both end up `isDefault`, and a question
   * replace can't land on a template published mid-flight.
   * ponytail: single global lock — template admin traffic is a few writes a
   * month, per-template locks would buy nothing.
   */
  private lockTemplates(tx: Prisma.TransactionClient) {
    // $executeRaw, not $queryRaw — the lock function returns `void`, which
    // Prisma cannot deserialize as a result column.
    return tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('banan_survey_templates'))`;
  }

  private async draftOr400(id: string) {
    const t = await this.prisma.surveyTemplate.findUnique({
      where: { id },
      select: { id: true, status: true },
    });
    if (!t) {
      throw new NotFoundException({
        code: 'SURVEY_TEMPLATE_NOT_FOUND',
        message: 'Không tìm thấy mẫu khảo sát.',
      });
    }
    if (t.status !== 'DRAFT') {
      // Published versions are IMMUTABLE — clone to a new draft to change.
      throw new BadRequestException({
        code: 'SURVEY_TEMPLATE_LOCKED',
        message: 'Bản đã publish không thể sửa — nhân bản thành bản nháp mới.',
      });
    }
    return t;
  }

  async updateTemplate(id: string, dto: UpdateSurveyTemplateDto) {
    await this.draftOr400(id);
    // Guarded write — a publish that landed between check and write loses.
    const done = await this.prisma.surveyTemplate.updateMany({
      where: { id, status: 'DRAFT' },
      data: { name: dto.name.trim() },
    });
    if (done.count === 0) {
      throw new BadRequestException({
        code: 'SURVEY_TEMPLATE_LOCKED',
        message: 'Bản đã publish không thể sửa — nhân bản thành bản nháp mới.',
      });
    }
    return this.templateDetail(id);
  }

  /** Replace a DRAFT's whole question set atomically (the editor saves the
   *  full list — no per-question CRUD to keep consistent). */
  async replaceQuestions(id: string, dto: ReplaceSurveyQuestionsDto) {
    await this.draftOr400(id);
    const codes = new Set<string>();
    for (const qq of dto.questions) {
      if (codes.has(qq.code)) {
        throw new BadRequestException({
          code: 'SURVEY_QUESTION_CODE_DUPLICATE',
          message: `Mã câu hỏi trùng: ${qq.code}`,
        });
      }
      codes.add(qq.code);
      const reservedType = RESERVED_QUESTION_TYPES[qq.code];
      if (reservedType && qq.type !== reservedType) {
        throw new BadRequestException({
          code: 'SURVEY_RESERVED_CODE_TYPE',
          message: `Mã "${qq.code}" là mã hệ thống (báo cáo dựa vào nó) — phải giữ loại ${reservedType}. Muốn loại khác, dùng mã mới.`,
        });
      }
      const isChoice = qq.type === 'SINGLE_CHOICE' || qq.type === 'MULTI_CHOICE';
      if (isChoice && !(qq.options && qq.options.length > 0)) {
        throw new BadRequestException({
          code: 'SURVEY_QUESTION_NEEDS_OPTIONS',
          message: `Câu hỏi lựa chọn cần ít nhất một lựa chọn: ${qq.code}`,
        });
      }
      if (!isChoice && qq.options && qq.options.length > 0) {
        throw new BadRequestException({
          code: 'SURVEY_QUESTION_NO_OPTIONS_ALLOWED',
          message: `Loại câu hỏi này không có lựa chọn: ${qq.code}`,
        });
      }
      const optValues = new Set<string>();
      for (const o of qq.options ?? []) {
        if (optValues.has(o.value)) {
          throw new BadRequestException({
            code: 'SURVEY_OPTION_VALUE_DUPLICATE',
            message: `Mã lựa chọn trùng trong ${qq.code}: ${o.value}`,
          });
        }
        optValues.add(o.value);
      }
    }
    for (const qq of dto.questions) {
      if (qq.showIfQuestionCode) {
        if (qq.showIfQuestionCode === qq.code || !codes.has(qq.showIfQuestionCode)) {
          throw new BadRequestException({
            code: 'SURVEY_CONDITION_INVALID',
            message: `Điều kiện hiển thị của ${qq.code} tham chiếu câu hỏi không tồn tại.`,
          });
        }
        if (!qq.showIfOp || qq.showIfValue == null) {
          throw new BadRequestException({
            code: 'SURVEY_CONDITION_INVALID',
            message: `Điều kiện hiển thị của ${qq.code} thiếu phép so sánh hoặc giá trị.`,
          });
        }
      }
    }
    await this.prisma.$transaction(async (tx) => {
      await this.lockTemplates(tx);
      // Re-check UNDER the lock — a concurrent publish must not get its
      // freshly-published question set overwritten.
      const cur = await tx.surveyTemplate.findUnique({ where: { id }, select: { status: true } });
      if (cur?.status !== 'DRAFT') {
        throw new BadRequestException({
          code: 'SURVEY_TEMPLATE_LOCKED',
          message: 'Bản đã publish không thể sửa — nhân bản thành bản nháp mới.',
        });
      }
      await tx.surveyQuestion.deleteMany({ where: { templateId: id } });
      for (const [idx, qq] of dto.questions.entries()) {
        await tx.surveyQuestion.create({
          data: {
            templateId: id,
            code: qq.code,
            type: qq.type as never,
            textVi: qq.textVi.trim(),
            textEn: qq.textEn.trim(),
            required: qq.required ?? false,
            sortOrder: idx,
            maxLength: qq.maxLength ?? null,
            showIfQuestionCode: qq.showIfQuestionCode ?? null,
            showIfOp: qq.showIfOp ?? null,
            showIfValue: qq.showIfValue ?? null,
            ...(qq.options && qq.options.length > 0
              ? {
                  options: {
                    create: qq.options.map((o, oIdx) => ({
                      value: o.value,
                      labelVi: o.labelVi.trim(),
                      labelEn: o.labelEn.trim(),
                      sortOrder: oIdx,
                    })),
                  },
                }
              : {}),
          },
        });
      }
    });
    return this.templateDetail(id);
  }

  /** Publish a draft as THE live default; the previous default is archived
   *  in the same tx (its responses keep pointing at it forever). All checks
   *  run UNDER the lock — a question replace or archive committing mid-flight
   *  cannot slip past them. */
  async publishTemplate(id: string) {
    await this.prisma.$transaction(async (tx) => {
      await this.lockTemplates(tx);
      const t = await tx.surveyTemplate.findUnique({
        where: { id },
        include: { questions: { select: { code: true, type: true, required: true } } },
      });
      if (!t) {
        throw new NotFoundException({
          code: 'SURVEY_TEMPLATE_NOT_FOUND',
          message: 'Không tìm thấy mẫu khảo sát.',
        });
      }
      // Two simultaneous publishes serialize on the lock — the second sees
      // the first's archive and cannot create a second default (there is no
      // partial unique index — this lock IS the guard).
      if (t.status !== 'DRAFT') {
        throw new BadRequestException({
          code: 'SURVEY_TEMPLATE_LOCKED',
          message: 'Chỉ publish được bản nháp.',
        });
      }
      // The case pipeline + dashboard key on THE question with code
      // "overall" — a custom emoji question under another code must never
      // be what opens cases and fires alert emails.
      if (
        !t.questions.some((qq) => qq.code === 'overall' && qq.type === 'EMOJI_SCALE' && qq.required)
      ) {
        throw new BadRequestException({
          code: 'SURVEY_TEMPLATE_NEEDS_OVERALL',
          message:
            'Mẫu cần câu cảm xúc tổng thể bắt buộc với mã "overall" (emoji 1–5) trước khi publish.',
        });
      }
      await tx.surveyTemplate.updateMany({
        where: { isDefault: true, id: { not: id } },
        data: { isDefault: false, status: 'ARCHIVED' },
      });
      await tx.surveyTemplate.update({
        where: { id },
        data: { status: 'PUBLISHED', isDefault: true, publishedAt: new Date() },
      });
    });
    return this.templateDetail(id);
  }

  async archiveTemplate(id: string) {
    // Same lock as publish — an archive that read "not default yet" must not
    // land AFTER a concurrent publish and kill the live template.
    await this.prisma.$transaction(async (tx) => {
      await this.lockTemplates(tx);
      const t = await tx.surveyTemplate.findUnique({
        where: { id },
        select: { isDefault: true, status: true },
      });
      if (!t) {
        throw new NotFoundException({
          code: 'SURVEY_TEMPLATE_NOT_FOUND',
          message: 'Không tìm thấy mẫu khảo sát.',
        });
      }
      if (t.isDefault && t.status === 'PUBLISHED') {
        throw new BadRequestException({
          code: 'SURVEY_TEMPLATE_IS_DEFAULT',
          message: 'Đây là mẫu đang chạy — publish một bản khác trước khi lưu trữ.',
        });
      }
      await tx.surveyTemplate.update({ where: { id }, data: { status: 'ARCHIVED' } });
    });
    return this.templateDetail(id);
  }

  /** Hard delete — DRAFTs only; anything with responses is archived, never
   *  deleted (audit history must survive). Drafts can't have responses.
   *  Locked like publish so a draft published mid-flight can't be deleted. */
  async deleteTemplate(id: string) {
    await this.prisma.$transaction(async (tx) => {
      await this.lockTemplates(tx);
      const t = await tx.surveyTemplate.findUnique({
        where: { id },
        include: { _count: { select: { responses: true } } },
      });
      if (!t) {
        throw new NotFoundException({
          code: 'SURVEY_TEMPLATE_NOT_FOUND',
          message: 'Không tìm thấy mẫu khảo sát.',
        });
      }
      if (t.status !== 'DRAFT' || t._count.responses > 0) {
        throw new BadRequestException({
          code: 'SURVEY_TEMPLATE_NOT_DELETABLE',
          message: 'Chỉ xóa được bản nháp chưa có phản hồi — dùng lưu trữ thay thế.',
        });
      }
      await tx.surveyTemplate.delete({ where: { id } });
    });
    return { ok: true };
  }

  // ── admin: rewards ────────────────────────────────────────────────────────

  async listCampaigns() {
    const rows = await this.prisma.surveyRewardCampaign.findMany({
      orderBy: { createdAt: 'desc' },
    });
    const counts = await this.prisma.surveyRewardClaim.groupBy({
      by: ['campaignId', 'status'],
      _count: { _all: true },
    });
    return rows.map((c) => {
      const of = (status: string) =>
        counts.find((x) => x.campaignId === c.id && x.status === status)?._count._all ?? 0;
      return {
        id: c.id,
        name: c.name,
        description: c.description,
        instructions: c.instructions,
        mode: c.mode,
        isEnabled: c.isEnabled,
        startsAt: c.startsAt?.toISOString() ?? null,
        endsAt: c.endsAt?.toISOString() ?? null,
        expiryDays: c.expiryDays,
        probabilityPct: c.probabilityPct,
        dailyCap: c.dailyCap,
        totalCap: c.totalCap,
        issuedCount: c.issuedCount,
        redeemedCount: of('REDEEMED'),
      };
    });
  }

  private campaignData(dto: CreateSurveyRewardDto | UpdateSurveyRewardDto) {
    return {
      ...(dto.name !== undefined ? { name: dto.name.trim() } : {}),
      ...(dto.description !== undefined ? { description: dto.description?.trim() || null } : {}),
      ...(dto.instructions !== undefined ? { instructions: dto.instructions?.trim() || null } : {}),
      ...(dto.mode !== undefined ? { mode: dto.mode as never } : {}),
      ...(dto.isEnabled !== undefined ? { isEnabled: dto.isEnabled } : {}),
      // Explicit null CLEARS a date/cap — omitting the field keeps it.
      ...(dto.startsAt !== undefined
        ? { startsAt: dto.startsAt ? new Date(dto.startsAt) : null }
        : {}),
      ...(dto.endsAt !== undefined ? { endsAt: dto.endsAt ? new Date(dto.endsAt) : null } : {}),
      ...(dto.expiryDays !== undefined ? { expiryDays: dto.expiryDays } : {}),
      ...(dto.probabilityPct !== undefined ? { probabilityPct: dto.probabilityPct } : {}),
      ...(dto.dailyCap !== undefined ? { dailyCap: dto.dailyCap } : {}),
      ...(dto.totalCap !== undefined ? { totalCap: dto.totalCap } : {}),
    };
  }

  /** Serializes campaign writes — the "one enabled" check + write must be
   *  atomic, two admins enabling at once both pass a plain pre-check. */
  private lockCampaigns(tx: Prisma.TransactionClient) {
    return tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('banan_survey_campaigns'))`;
  }

  /** Effective-value checks: valid window + at most ONE enabled campaign
   *  (activeCampaign "latest wins" tie-break must never silently decide).
   *  Call UNDER lockCampaigns, in the same tx as the write. */
  private async guardCampaign(
    tx: Prisma.TransactionClient,
    dto: CreateSurveyRewardDto | UpdateSurveyRewardDto,
    existing: { id: string; isEnabled: boolean; startsAt: Date | null; endsAt: Date | null } | null,
  ) {
    const startsAt =
      dto.startsAt !== undefined
        ? dto.startsAt
          ? new Date(dto.startsAt)
          : null
        : (existing?.startsAt ?? null);
    const endsAt =
      dto.endsAt !== undefined
        ? dto.endsAt
          ? new Date(dto.endsAt)
          : null
        : (existing?.endsAt ?? null);
    if (startsAt && endsAt && startsAt > endsAt) {
      throw new BadRequestException({
        code: 'SURVEY_CAMPAIGN_WINDOW_INVALID',
        message: 'Ngày bắt đầu phải trước ngày kết thúc.',
      });
    }
    const enabled = dto.isEnabled ?? existing?.isEnabled ?? false;
    if (enabled) {
      const other = await tx.surveyRewardCampaign.findFirst({
        where: { isEnabled: true, ...(existing ? { id: { not: existing.id } } : {}) },
        select: { name: true },
      });
      if (other) {
        throw new BadRequestException({
          code: 'SURVEY_CAMPAIGN_ALREADY_ENABLED',
          message: `Đang bật "${other.name}" — tắt chương trình đó trước.`,
        });
      }
    }
  }

  async createCampaign(dto: CreateSurveyRewardDto) {
    await this.prisma.$transaction(async (tx) => {
      await this.lockCampaigns(tx);
      await this.guardCampaign(tx, dto, null);
      await tx.surveyRewardCampaign.create({
        data: { ...this.campaignData(dto), name: dto.name.trim() },
      });
    });
    return this.listCampaigns();
  }

  async updateCampaign(id: string, dto: UpdateSurveyRewardDto) {
    await this.prisma.$transaction(async (tx) => {
      await this.lockCampaigns(tx);
      const exists = await tx.surveyRewardCampaign.findUnique({
        where: { id },
        select: { id: true, isEnabled: true, startsAt: true, endsAt: true },
      });
      if (!exists) {
        throw new NotFoundException({
          code: 'SURVEY_CAMPAIGN_NOT_FOUND',
          message: 'Không tìm thấy chương trình quà.',
        });
      }
      await this.guardCampaign(tx, dto, exists);
      await tx.surveyRewardCampaign.update({ where: { id }, data: this.campaignData(dto) });
    });
    return this.listCampaigns();
  }

  /** Staff keys the voucher code in at the counter — ISSUED→REDEEMED with a
   *  guarded update so a double-scan can't redeem twice. */
  async redeemClaim(dto: RedeemSurveyRewardDto, actorId: string) {
    const code = dto.code.trim().toUpperCase();
    const claim = await this.prisma.surveyRewardClaim.findUnique({
      where: { voucherCode: code },
      include: {
        campaign: { select: { name: true } },
        response: { select: { storeName: true, createdAt: true } },
      },
    });
    if (!claim) {
      throw new NotFoundException({
        code: 'SURVEY_REWARD_CODE_NOT_FOUND',
        message: 'Không tìm thấy mã quà này.',
      });
    }
    if (claim.status === 'REDEEMED') {
      throw new BadRequestException({
        code: 'SURVEY_REWARD_ALREADY_REDEEMED',
        message: `Mã đã được đổi lúc ${claim.redeemedAt?.toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' }) ?? '?'}.`,
      });
    }
    if (claim.status === 'VOID') {
      throw new BadRequestException({
        code: 'SURVEY_REWARD_VOID',
        message: 'Mã đã bị hủy.',
      });
    }
    if (claim.expiresAt && claim.expiresAt < new Date()) {
      await this.prisma.surveyRewardClaim.updateMany({
        where: { id: claim.id, status: 'ISSUED' },
        data: { status: 'EXPIRED' },
      });
      throw new BadRequestException({
        code: 'SURVEY_REWARD_EXPIRED',
        message: 'Mã đã hết hạn.',
      });
    }
    const done = await this.prisma.surveyRewardClaim.updateMany({
      where: { id: claim.id, status: 'ISSUED' },
      data: { status: 'REDEEMED', redeemedAt: new Date(), redeemedById: actorId },
    });
    if (done.count === 0) {
      throw new BadRequestException({
        code: 'SURVEY_REWARD_ALREADY_REDEEMED',
        message: 'Mã vừa được đổi ở nơi khác.',
      });
    }
    return {
      voucherCode: claim.voucherCode,
      campaignName: claim.campaign.name,
      storeName: claim.response.storeName,
      issuedAt: claim.createdAt.toISOString(),
      expiresAt: claim.expiresAt?.toISOString() ?? null,
    };
  }

  async listClaims(q: SurveyClaimsQueryDto) {
    const page = q.page ?? 1;
    const perPage = q.perPage ?? 50;
    const rows = await this.prisma.surveyRewardClaim.findMany({
      where: {
        ...(q.campaignId ? { campaignId: q.campaignId } : {}),
        ...(q.status ? { status: q.status as never } : {}),
      },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * perPage,
      take: perPage,
      include: {
        campaign: { select: { name: true, mode: true } },
        response: { select: { storeName: true } },
      },
    });
    return rows.map((c) => ({
      id: c.id,
      voucherCode: c.voucherCode,
      status: c.status,
      campaignName: c.campaign.name,
      mode: c.campaign.mode,
      storeName: c.response.storeName,
      issuedAt: c.createdAt.toISOString(),
      expiresAt: c.expiresAt?.toISOString() ?? null,
      redeemedAt: c.redeemedAt?.toISOString() ?? null,
    }));
  }
}

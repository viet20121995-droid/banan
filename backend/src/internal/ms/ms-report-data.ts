import { NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import type { MsPdfData } from '../pdf/internal-pdf.service';
import { hcmDate, hcmTime } from '../qc/qc-report-data';

import { scoreMs, type MsResult } from './ms-scoring';

export interface MsReportBundle {
  pdf: MsPdfData;
  result: MsResult;
  code: string;
  revision: number;
  storeName: string;
  performedDateLabel: string;
  timeline: { label: string; value: string }[];
  purchaseSummary: string | null;
  issues: string[];
  criticalTexts: string[];
  overallComment: string | null;
}

export const MS_DETAIL_INCLUDE = {
  store: { select: { id: true, name: true, slug: true } },
  template: {
    include: {
      sections: {
        orderBy: { sortOrder: 'asc' as const },
        include: { questions: { orderBy: { sortOrder: 'asc' as const } } },
      },
    },
  },
  submission: {
    include: {
      answers: { include: { evidence: true } },
      evidence: true,
    },
  },
};

export type MsAssignmentPayload = Prisma.MsAssignmentGetPayload<{
  include: typeof MS_DETAIL_INCLUDE;
}>;

/** Minimal read surface — satisfied by PrismaService AND a tx client, so
 *  approve() can score inside its own locked transaction. */
export interface MsReadDb {
  msAssignment: {
    findUnique: (args: {
      where: { id: string };
      include: typeof MS_DETAIL_INCLUDE;
    }) => Promise<MsAssignmentPayload | null>;
  };
}

const TIMELINE_FIELDS: {
  key: 'enteredAt' | 'greetedAt' | 'orderStartAt' | 'paidAt' | 'receivedAt';
  label: string;
}[] = [
  { key: 'enteredAt', label: 'Giờ bước vào' },
  { key: 'greetedAt', label: 'Giờ được chào' },
  { key: 'orderStartAt', label: 'Giờ bắt đầu đặt' },
  { key: 'paidAt', label: 'Giờ thanh toán' },
  { key: 'receivedAt', label: 'Giờ nhận món' },
];

/** Pure: scores + shapes an already-loaded assignment into the bundle. */
export function buildMsReportBundle(assignment: MsAssignmentPayload): MsReportBundle {
  const submission = assignment.submission;
  const answerByQuestion = new Map((submission?.answers ?? []).map((a) => [a.questionId, a]));

  const result = scoreMs(
    assignment.template.sections.map((s) => ({
      sectionId: s.id,
      code: s.code,
      title: s.title,
      kind: s.kind,
      weight: s.weight,
      values: s.questions.map((q) => answerByQuestion.get(q.id)?.value ?? null),
    })),
  );
  const scoreBySection = new Map(result.sections.map((s) => [s.sectionId, s]));

  const performed = submission?.enteredAt ?? assignment.windowStart ?? assignment.createdAt;
  const performedDateLabel = hcmDate(performed);

  const timeline = TIMELINE_FIELDS.map((f) => ({
    label: f.label,
    value: submission?.[f.key] ? hcmTime(submission[f.key] as Date) : '—',
  }));

  const purchaseParts = [
    submission?.productsBought,
    submission?.amountPaidVnd != null
      ? `${submission.amountPaidVnd.toLocaleString('vi-VN')}₫`
      : null,
  ].filter(Boolean);
  const purchaseSummary = purchaseParts.length > 0 ? purchaseParts.join(' · ') : null;

  const issues: string[] = [];
  const scoredSections = assignment.template.sections.filter((s) => s.kind === 'SCORED');
  for (const s of scoredSections) {
    for (const q of s.questions) {
      const a = answerByQuestion.get(q.id);
      if (a?.value === 'NO') {
        issues.push(`[${s.code}] ${q.text}${a.note ? ` — ${a.note}` : ''}`);
      }
    }
  }

  const criticalSection = assignment.template.sections.find((s) => s.kind === 'CRITICAL');
  const criticals = (criticalSection?.questions ?? []).map((q) => {
    const a = answerByQuestion.get(q.id);
    return {
      text: q.text,
      occurred: a?.value === 'YES',
      note: a?.note ?? undefined,
      evidence: (a?.evidence ?? []).map((e) => ({ url: e.url })),
    };
  });

  const pdf: MsPdfData = {
    code: assignment.code,
    revision: assignment.approvedRevision,
    storeName: assignment.store.name,
    performedDate: performedDateLabel,
    outcome: result.outcome,
    totalScore: result.totalScore,
    criticalFail: result.criticalFail,
    timeline,
    purchase: [
      { label: 'Sản phẩm mua', value: submission?.productsBought || '—' },
      {
        label: 'Giá thực trả',
        value:
          submission?.amountPaidVnd != null
            ? `${submission.amountPaidVnd.toLocaleString('vi-VN')}₫`
            : '—',
      },
      { label: 'Nhân viên (bảng tên)', value: submission?.staffName || '—' },
    ],
    sections: scoredSections.map((s) => ({
      code: s.code,
      title: s.title,
      weight: s.weight,
      score: scoreBySection.get(s.id)?.score ?? null,
      questions: s.questions.map((q) => {
        const a = answerByQuestion.get(q.id);
        return {
          text: q.text,
          value: a?.value ?? null,
          note: a?.note ?? undefined,
          evidence: (a?.evidence ?? []).map((e) => ({ url: e.url })),
        };
      }),
    })),
    criticals,
    overallComment: submission?.overallComment ?? undefined,
  };

  return {
    pdf,
    result,
    code: assignment.code,
    revision: assignment.approvedRevision,
    storeName: assignment.store.name,
    performedDateLabel,
    timeline,
    purchaseSummary,
    issues,
    criticalTexts: criticals.filter((c) => c.occurred).map((c) => c.text),
    overallComment: submission?.overallComment ?? null,
  };
}

/** Loads + scores an MS assignment into the report bundle. */
export async function loadMsReportBundle(
  db: MsReadDb,
  assignmentId: string,
): Promise<MsReportBundle> {
  const assignment = await db.msAssignment.findUnique({
    where: { id: assignmentId },
    include: MS_DETAIL_INCLUDE,
  });
  if (!assignment) {
    throw new NotFoundException({
      code: 'INTERNAL_MS_NOT_FOUND',
      message: 'Không tìm thấy nhiệm vụ.',
    });
  }
  return buildMsReportBundle(assignment);
}

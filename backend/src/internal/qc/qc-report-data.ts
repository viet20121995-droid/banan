import { NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import type { QcPdfData } from '../pdf/internal-pdf.service';

import { scoreQc, type QcResult } from './qc-scoring';

/** Everything the PDF + report email need, loaded and scored in one place.
 *  Deliberately JSON-safe (strings/numbers only, no Date) — complete/approve
 *  persist it verbatim as the delivery row's immutable `reportSnapshot`. */
export interface QcReportBundle {
  pdf: QcPdfData;
  result: QcResult;
  storeName: string;
  inspectionId: string;
  code: string;
  revision: number;
  inspectionDateLabel: string;
  inspectorName: string;
  failedItems: { section: string; no: string; text: string; detail: string | null }[];
  occurredRisks: string[];
}

const HCM_TZ = 'Asia/Ho_Chi_Minh';

export function hcmDate(d: Date): string {
  return d.toLocaleDateString('vi-VN', {
    timeZone: HCM_TZ,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
}

export function hcmTime(d: Date): string {
  return d.toLocaleTimeString('vi-VN', { timeZone: HCM_TZ, hour: '2-digit', minute: '2-digit' });
}

/** Short human report code — id prefix is stable and unique enough to trace. */
export function qcReportCode(inspection: { id: string; inspectionDate: Date }): string {
  const d = new Date(inspection.inspectionDate.getTime() + 7 * 3600_000);
  const ymd = `${d.getUTCFullYear()}${String(d.getUTCMonth() + 1).padStart(2, '0')}${String(d.getUTCDate()).padStart(2, '0')}`;
  return `QC-${ymd}-${inspection.id.slice(0, 6).toUpperCase()}`;
}

export const QC_DETAIL_INCLUDE = {
  store: { select: { id: true, name: true, slug: true } },
  template: {
    include: {
      sections: {
        orderBy: { sortOrder: 'asc' as const },
        include: { items: { orderBy: { sortOrder: 'asc' as const } } },
      },
    },
  },
  answers: { include: { evidence: true } },
  riskAnswers: { include: { evidence: true } },
};

export type QcInspectionPayload = Prisma.QcInspectionGetPayload<{
  include: typeof QC_DETAIL_INCLUDE;
}>;

/** Minimal read surface — satisfied by both PrismaService and a tx client,
 *  so complete() can score INSIDE its locked transaction. */
export interface QcReadDb {
  qcInspection: {
    findUnique: (args: {
      where: { id: string };
      include: typeof QC_DETAIL_INCLUDE;
    }) => Promise<QcInspectionPayload | null>;
  };
}

/** Pure: scores + shapes an already-loaded inspection into the bundle. */
export function buildQcReportBundle(inspection: QcInspectionPayload): QcReportBundle {
  const answerByItem = new Map(inspection.answers.map((a) => [a.itemId, a]));
  const riskByItem = new Map(inspection.riskAnswers.map((r) => [r.itemId, r]));

  const normalSections = inspection.template.sections.filter((s) => !s.isRisk);
  const riskSection = inspection.template.sections.find((s) => s.isRisk);

  const result = scoreQc(
    inspection.template.sections.map((s) => ({
      sectionId: s.id,
      title: s.title,
      isRisk: s.isRisk,
      values: s.items.map((it) => answerByItem.get(it.id)?.value ?? null),
    })),
    (riskSection?.items ?? []).some((it) => riskByItem.get(it.id)?.occurred === true),
  );
  const sectionScoreById = new Map(result.sections.map((s) => [s.sectionId, s]));

  const failedItems: QcReportBundle['failedItems'] = [];
  const pdfSections: QcPdfData['sections'] = normalSections.map((s) => {
    const score = sectionScoreById.get(s.id);
    return {
      title: s.title,
      percent: score?.percent ?? null,
      passCount: score?.passCount ?? 0,
      applicable: score?.applicable ?? 0,
      naCount: score?.naCount ?? 0,
      items: s.items.map((it, idx) => {
        const a = answerByItem.get(it.id);
        if (a?.value === 'FAIL') {
          failedItems.push({
            section: s.title,
            no: String(idx + 1),
            text: it.text,
            detail: a.failDetail ?? null,
          });
        }
        return {
          no: String(idx + 1),
          text: it.text,
          value: a?.value ?? null,
          failDetail: a?.failDetail ?? undefined,
          naReason: a?.naReason ?? undefined,
          evidence: (a?.evidence ?? []).map((e) => ({ url: e.url })),
        };
      }),
    };
  });

  const risks: QcPdfData['risks'] = (riskSection?.items ?? []).map((it) => {
    const r = riskByItem.get(it.id);
    return {
      text: it.text,
      occurred: r?.occurred ?? null,
      detail: r?.detail ?? undefined,
      evidence: (r?.evidence ?? []).map((e) => ({ url: e.url })),
    };
  });

  const code = qcReportCode(inspection);
  const pdf: QcPdfData = {
    code,
    revision: inspection.revision,
    storeName: inspection.store.name,
    inspectionDate: hcmDate(inspection.inspectionDate),
    startedAt: inspection.startedAt ? hcmTime(inspection.startedAt) : undefined,
    endedAt: inspection.endedAt ? hcmTime(inspection.endedAt) : undefined,
    inspectorName: inspection.inspectorName,
    staffOnShift: inspection.staffOnShift ?? undefined,
    generalNotes: inspection.generalNotes ?? undefined,
    outcome: result.outcome,
    overallPercent: result.overallPercent,
    overallPass: result.overallPass,
    overallApplicable: result.overallApplicable,
    sections: pdfSections,
    risks,
  };

  return {
    pdf,
    result,
    storeName: inspection.store.name,
    inspectionId: inspection.id,
    code,
    revision: inspection.revision,
    inspectionDateLabel: hcmDate(inspection.inspectionDate),
    inspectorName: inspection.inspectorName,
    failedItems,
    occurredRisks: risks.filter((r) => r.occurred === true).map((r) => r.text),
  };
}

/** Loads + scores a QC inspection into the report bundle. Throws NotFound.
 *  Accepts a tx client so callers can score under their own row lock. */
export async function loadQcReportBundle(
  db: QcReadDb,
  inspectionId: string,
): Promise<QcReportBundle> {
  const inspection = await db.qcInspection.findUnique({
    where: { id: inspectionId },
    include: QC_DETAIL_INCLUDE,
  });
  if (!inspection) {
    throw new NotFoundException({
      code: 'INTERNAL_QC_NOT_FOUND',
      message: 'Không tìm thấy phiên kiểm tra.',
    });
  }
  return buildQcReportBundle(inspection);
}

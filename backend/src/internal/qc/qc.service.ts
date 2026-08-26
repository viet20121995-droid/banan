import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { assertPrivateFileName, removePrivateFile } from '../files/internal-files.util';
import { qcReportRecipients } from '../internal-config';

import type {
  AttachEvidenceDto,
  CreateQcInspectionDto,
  QcCompareQueryDto,
  QcListQueryDto,
  UpdateQcInspectionDto,
  UpsertQcAnswerDto,
  UpsertQcRiskDto,
} from './dto';
import {
  QC_DETAIL_INCLUDE,
  buildQcReportBundle,
  loadQcReportBundle,
  qcReportCode,
} from './qc-report-data';
import { QC_TEMPLATE_NAME } from './qc-template-data';

/** Row shape returned by the FOR UPDATE lock query. */
interface LockedInspection {
  id: string;
  status: string;
  templateId: string;
}

@Injectable()
export class QcService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  /** Active template (latest active version) — the form the app renders. */
  async activeTemplate() {
    const template = await this.prisma.qcTemplate.findFirst({
      where: { name: QC_TEMPLATE_NAME, isActive: true },
      orderBy: { version: 'desc' },
      include: {
        sections: {
          orderBy: { sortOrder: 'asc' },
          include: { items: { orderBy: { sortOrder: 'asc' } } },
        },
      },
    });
    if (!template) {
      throw new BadRequestException({
        code: 'INTERNAL_QC_NO_TEMPLATE',
        message: 'Chưa có mẫu QC. Chạy seed trước khi sử dụng.',
      });
    }
    return template;
  }

  async create(dto: CreateQcInspectionDto, actorId: string, actorName: string) {
    const store = await this.prisma.store.findUnique({ where: { id: dto.storeId } });
    if (!store) {
      throw new BadRequestException({
        code: 'INTERNAL_QC_STORE_NOT_FOUND',
        message: 'Chi nhánh không tồn tại.',
      });
    }
    const template = await this.activeTemplate();
    const inspection = await this.prisma.qcInspection.create({
      data: {
        templateId: template.id,
        storeId: store.id,
        inspectionDate: new Date(dto.inspectionDate),
        inspectorName: dto.inspectorName?.trim() || actorName,
        staffOnShift: dto.staffOnShift?.trim() || null,
        createdById: actorId,
      },
      include: QC_DETAIL_INCLUDE,
    });
    return this.toDetailView(inspection);
  }

  async list(query: QcListQueryDto, page = 1, perPage = 30) {
    const where: Prisma.QcInspectionWhereInput = {
      ...(query.storeId && { storeId: query.storeId }),
      ...(query.status && { status: query.status }),
      ...(query.outcome && { outcome: query.outcome }),
      ...((query.from || query.to) && {
        inspectionDate: {
          ...(query.from && { gte: new Date(query.from) }),
          ...(query.to && { lte: new Date(query.to) }),
        },
      }),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.qcInspection.findMany({
        where,
        include: {
          store: { select: { id: true, name: true } },
          riskAnswers: { where: { occurred: true }, select: { id: true } },
        },
        orderBy: { inspectionDate: 'desc' },
        skip: (page - 1) * perPage,
        take: perPage,
      }),
      this.prisma.qcInspection.count({ where }),
    ]);
    return {
      items: items.map((i) => ({
        id: i.id,
        code: qcReportCode(i),
        store: i.store,
        inspectionDate: i.inspectionDate.toISOString(),
        status: i.status,
        outcome: i.outcome,
        overallPercent: i.overallPercent,
        revision: i.revision,
        riskCount: i.riskAnswers.length,
        inspectorName: i.inspectorName,
        completedAt: i.completedAt?.toISOString() ?? null,
      })),
      meta: { page, perPage, total },
    };
  }

  async detail(id: string) {
    const inspection = await this.prisma.qcInspection.findUnique({
      where: { id },
      include: QC_DETAIL_INCLUDE,
    });
    if (!inspection) this.notFound();
    return this.toDetailView(inspection);
  }

  async updateHeader(id: string, dto: UpdateQcInspectionDto, actorId: string) {
    await this.prisma.$transaction(async (tx) => {
      const locked = await this.lockInspection(tx, id);
      this.assertMutable(locked);
      await tx.qcInspection.update({
        where: { id },
        data: {
          ...(dto.inspectionDate && { inspectionDate: new Date(dto.inspectionDate) }),
          ...(dto.startedAt !== undefined && {
            startedAt: dto.startedAt ? new Date(dto.startedAt) : null,
          }),
          ...(dto.endedAt !== undefined && {
            endedAt: dto.endedAt ? new Date(dto.endedAt) : null,
          }),
          ...(dto.inspectorName !== undefined && { inspectorName: dto.inspectorName.trim() }),
          ...(dto.staffOnShift !== undefined && {
            staffOnShift: dto.staffOnShift?.trim() || null,
          }),
          ...(dto.generalNotes !== undefined && {
            generalNotes: dto.generalNotes?.trim() || null,
          }),
          updatedById: actorId,
        },
      });
    });
    return this.detail(id);
  }

  /** Upsert one normal-item answer. Runs under the inspection row lock so it
   *  can never interleave with complete(); ownership: the item must belong
   *  to the inspection's own template — client ids are never trusted. */
  async upsertAnswer(
    inspectionId: string,
    itemId: string,
    dto: UpsertQcAnswerDto,
    actorId: string,
  ) {
    if (dto.value === 'NOT_AVAILABLE' && !dto.naReason?.trim()) {
      throw new BadRequestException({
        code: 'INTERNAL_QC_NA_REASON_REQUIRED',
        message: 'Chọn N/A phải ghi lý do.',
      });
    }
    await this.prisma.$transaction(async (tx) => {
      const locked = await this.lockInspection(tx, inspectionId);
      this.assertMutable(locked);
      await this.assertItem(tx, locked, itemId, { risk: false });
      await tx.qcInspectionAnswer.upsert({
        where: { inspectionId_itemId: { inspectionId, itemId } },
        create: {
          inspectionId,
          itemId,
          value: dto.value,
          failDetail: dto.value === 'FAIL' ? dto.failDetail?.trim() || null : null,
          naReason: dto.value === 'NOT_AVAILABLE' ? dto.naReason!.trim() : null,
        },
        update: {
          value: dto.value,
          failDetail: dto.value === 'FAIL' ? dto.failDetail?.trim() || null : null,
          naReason: dto.value === 'NOT_AVAILABLE' ? (dto.naReason?.trim() ?? null) : null,
        },
      });
      await this.markInProgress(tx, inspectionId, actorId);
    });
    return this.detail(inspectionId);
  }

  async upsertRisk(inspectionId: string, itemId: string, dto: UpsertQcRiskDto, actorId: string) {
    if (dto.occurred && !dto.detail?.trim()) {
      throw new BadRequestException({
        code: 'INTERNAL_QC_RISK_DETAIL_REQUIRED',
        message: 'Risk xảy ra phải ghi chi tiết.',
      });
    }
    await this.prisma.$transaction(async (tx) => {
      const locked = await this.lockInspection(tx, inspectionId);
      this.assertMutable(locked);
      await this.assertItem(tx, locked, itemId, { risk: true });
      await tx.qcRiskAnswer.upsert({
        where: { inspectionId_itemId: { inspectionId, itemId } },
        create: {
          inspectionId,
          itemId,
          occurred: dto.occurred,
          detail: dto.occurred ? dto.detail!.trim() : null,
        },
        update: {
          occurred: dto.occurred,
          detail: dto.occurred ? (dto.detail?.trim() ?? null) : null,
        },
      });
      await this.markInProgress(tx, inspectionId, actorId);
    });
    return this.detail(inspectionId);
  }

  /** Attach a PRIVATE uploaded image (by generated file name) to a normal
   *  answer or a risk answer. */
  async attachEvidence(
    inspectionId: string,
    itemId: string,
    dto: AttachEvidenceDto,
    actorId: string,
  ) {
    assertPrivateFileName(dto.name, 'INTERNAL_QC');
    await this.prisma.$transaction(async (tx) => {
      const locked = await this.lockInspection(tx, inspectionId);
      this.assertMutable(locked);
      const item = await tx.qcItem.findUnique({
        where: { id: itemId },
        include: { section: { select: { templateId: true, isRisk: true } } },
      });
      if (!item || item.section.templateId !== locked.templateId) {
        throw new BadRequestException({
          code: 'INTERNAL_QC_ITEM_MISMATCH',
          message: 'Tiêu chí không thuộc phiên kiểm tra này.',
        });
      }
      if (item.section.isRisk) {
        const answer = await tx.qcRiskAnswer.findUnique({
          where: { inspectionId_itemId: { inspectionId, itemId } },
        });
        if (!answer) this.answerFirst();
        await tx.qcEvidence.create({
          data: {
            riskAnswerId: answer.id,
            url: dto.name,
            mimeType: dto.mimeType,
            sizeBytes: dto.sizeBytes,
            createdById: actorId,
          },
        });
      } else {
        const answer = await tx.qcInspectionAnswer.findUnique({
          where: { inspectionId_itemId: { inspectionId, itemId } },
        });
        if (!answer) this.answerFirst();
        await tx.qcEvidence.create({
          data: {
            answerId: answer.id,
            url: dto.name,
            mimeType: dto.mimeType,
            sizeBytes: dto.sizeBytes,
            createdById: actorId,
          },
        });
      }
    });
    return this.detail(inspectionId);
  }

  async removeEvidence(inspectionId: string, evidenceId: string) {
    const fileName = await this.prisma.$transaction(async (tx) => {
      const locked = await this.lockInspection(tx, inspectionId);
      this.assertMutable(locked);
      const ev = await tx.qcEvidence.findUnique({
        where: { id: evidenceId },
        include: {
          answer: { select: { inspectionId: true } },
          riskAnswer: { select: { inspectionId: true } },
        },
      });
      const owner = ev?.answer?.inspectionId ?? ev?.riskAnswer?.inspectionId;
      if (!ev || owner !== inspectionId) {
        throw new NotFoundException({
          code: 'INTERNAL_QC_EVIDENCE_NOT_FOUND',
          message: 'Không tìm thấy ảnh.',
        });
      }
      await tx.qcEvidence.delete({ where: { id: ev.id } });
      return ev.url;
    });
    // Only after the DB row is gone — a failed tx must not lose the file.
    removePrivateFile(fileName);
    return this.detail(inspectionId);
  }

  /**
   * Completes the inspection. The WHOLE flow — row lock, load answers,
   * validate, score, status transition, delivery row — runs in ONE
   * transaction, so a concurrent answer write either lands before the lock
   * (and is scored) or blocks until after COMPLETED (and is rejected). The
   * status-guarded updateMany + unique (inspectionId, revision) still stop
   * a double-complete.
   */
  async complete(id: string, actorId: string): Promise<{ inspectionId: string; revision: number }> {
    const recipients = qcReportRecipients(this.config);
    const revision = await this.prisma.$transaction(
      async (tx) => {
        const locked = await this.lockInspection(tx, id);
        this.assertMutable(locked);
        const inspection = await tx.qcInspection.findUniqueOrThrow({
          where: { id },
          include: QC_DETAIL_INCLUDE,
        });

        // ── validation (under the lock — nothing can change beneath us) ──
        const problems: string[] = [];
        const answerByItem = new Map(inspection.answers.map((a) => [a.itemId, a]));
        const riskByItem = new Map(inspection.riskAnswers.map((r) => [r.itemId, r]));
        for (const section of inspection.template.sections) {
          for (const item of section.items) {
            if (section.isRisk) {
              const r = riskByItem.get(item.id);
              if (r?.occurred == null) problems.push(`Chưa trả lời Risk: ${item.text}`);
              else if (r.occurred) {
                if (!r.detail?.trim()) problems.push(`Risk thiếu chi tiết: ${item.text}`);
                if (r.evidence.length === 0) {
                  problems.push(`Risk thiếu ảnh bằng chứng: ${item.text}`);
                }
              }
            } else {
              const a = answerByItem.get(item.id);
              if (!a?.value) problems.push(`Chưa trả lời: ${item.text}`);
              else if (a.value === 'FAIL') {
                if (!a.failDetail?.trim()) problems.push(`FAIL thiếu chi tiết lỗi: ${item.text}`);
                if (a.evidence.length === 0) {
                  problems.push(`FAIL thiếu ảnh bằng chứng: ${item.text}`);
                }
              } else if (a.value === 'NOT_AVAILABLE' && !a.naReason?.trim()) {
                problems.push(`N/A thiếu lý do: ${item.text}`);
              }
            }
          }
        }
        if (problems.length > 0) {
          throw new BadRequestException({
            code: 'INTERNAL_QC_INCOMPLETE',
            message: 'Chưa thể hoàn tất — còn mục chưa hợp lệ.',
            details: problems,
          });
        }

        const bundle = buildQcReportBundle(inspection);
        const claimed = await tx.qcInspection.updateMany({
          where: { id, status: { in: ['DRAFT', 'IN_PROGRESS'] } },
          data: {
            status: 'COMPLETED',
            completedAt: new Date(),
            completedById: actorId,
            revision: { increment: 1 },
            outcome: bundle.result.outcome,
            overallPercent: bundle.result.overallPercent,
          },
        });
        if (claimed.count === 0) {
          throw new BadRequestException({
            code: 'INTERNAL_QC_ALREADY_COMPLETED',
            message: 'Phiên kiểm tra đã được hoàn tất.',
          });
        }
        const fresh = await tx.qcInspection.findUniqueOrThrow({
          where: { id },
          select: { revision: true },
        });
        // The bundle was scored BEFORE the revision increment — stamp the
        // final revision, then freeze it as the delivery's immutable
        // snapshot. The dispatcher renders from THIS, never from live data.
        bundle.revision = fresh.revision;
        bundle.pdf.revision = fresh.revision;
        await tx.qcReportDelivery.create({
          data: {
            inspectionId: id,
            revision: fresh.revision,
            recipients,
            reportSnapshot: bundle as unknown as Prisma.InputJsonValue,
          },
        });
        return fresh.revision;
      },
      { timeout: 15_000 },
    );
    return { inspectionId: id, revision };
  }

  /** COMPLETED → IN_PROGRESS so admin can fix answers; the next complete
   *  produces the next revision (and its own report email). */
  async reopen(id: string, actorId: string) {
    const claimed = await this.prisma.qcInspection.updateMany({
      where: { id, status: 'COMPLETED' },
      data: { status: 'IN_PROGRESS', reopenedAt: new Date(), reopenedById: actorId },
    });
    if (claimed.count === 0) {
      throw new BadRequestException({
        code: 'INTERNAL_QC_NOT_COMPLETED',
        message: 'Chỉ mở lại được phiên đã hoàn tất.',
      });
    }
    return this.detail(id);
  }

  /** Live score preview + report bundle (also used by the PDF endpoint). */
  reportBundle(id: string) {
    return loadQcReportBundle(this.prisma, id);
  }

  /** Per-store aggregates over completed inspections in a range. */
  async compare(query: QcCompareQueryDto) {
    const stores = await this.prisma.store.findMany({
      select: { id: true, name: true, slug: true },
      orderBy: { createdAt: 'asc' },
    });
    const inspections = await this.prisma.qcInspection.findMany({
      where: {
        status: 'COMPLETED',
        inspectionDate: { gte: new Date(query.from), lte: new Date(query.to) },
      },
      select: { storeId: true, outcome: true, overallPercent: true },
    });
    return {
      stores: stores.map((store) => {
        const mine = inspections.filter((i) => i.storeId === store.id);
        const withPercent = mine.filter((i) => i.overallPercent != null);
        const avg =
          withPercent.length === 0
            ? null
            : Math.round(
                (withPercent.reduce((s, i) => s + (i.overallPercent ?? 0), 0) /
                  withPercent.length) *
                  100,
              ) / 100;
        return {
          store,
          inspections: mine.length,
          avgPercent: avg,
          pass: mine.filter((i) => i.outcome === 'PASS').length,
          fail: mine.filter((i) => i.outcome === 'FAIL').length,
          criticalFail: mine.filter((i) => i.outcome === 'CRITICAL_FAIL').length,
        };
      }),
    };
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /** Locks the inspection row FOR UPDATE — every writer (answers, evidence,
   *  header, complete) serialises on this, in the same lock order. */
  private async lockInspection(
    tx: Prisma.TransactionClient,
    id: string,
  ): Promise<LockedInspection> {
    const rows = await tx.$queryRaw<LockedInspection[]>`
      SELECT id, status, "templateId" FROM "QcInspection" WHERE id = ${id} FOR UPDATE`;
    if (rows.length === 0) this.notFound();
    return rows[0];
  }

  private assertMutable(locked: LockedInspection): void {
    if (locked.status === 'COMPLETED') {
      throw new BadRequestException({
        code: 'INTERNAL_QC_LOCKED',
        message: 'Kết quả đã hoàn tất — dùng "Mở lại" để chỉnh sửa.',
      });
    }
  }

  private async assertItem(
    tx: Prisma.TransactionClient,
    locked: LockedInspection,
    itemId: string,
    opts: { risk: boolean },
  ): Promise<void> {
    const item = await tx.qcItem.findUnique({
      where: { id: itemId },
      include: { section: { select: { templateId: true, isRisk: true } } },
    });
    if (
      !item ||
      item.section.templateId !== locked.templateId ||
      item.section.isRisk !== opts.risk
    ) {
      throw new BadRequestException({
        code: 'INTERNAL_QC_ITEM_MISMATCH',
        message: 'Tiêu chí không thuộc phiên kiểm tra này.',
      });
    }
  }

  private async markInProgress(
    tx: Prisma.TransactionClient,
    id: string,
    actorId: string,
  ): Promise<void> {
    await tx.qcInspection.updateMany({
      where: { id, status: 'DRAFT' },
      data: { status: 'IN_PROGRESS', updatedById: actorId },
    });
  }

  private notFound(): never {
    throw new NotFoundException({
      code: 'INTERNAL_QC_NOT_FOUND',
      message: 'Không tìm thấy phiên kiểm tra.',
    });
  }

  private answerFirst(): never {
    throw new BadRequestException({
      code: 'INTERNAL_QC_ANSWER_FIRST',
      message: 'Trả lời tiêu chí trước khi đính kèm ảnh.',
    });
  }

  private toDetailView(
    inspection: Prisma.QcInspectionGetPayload<{ include: typeof QC_DETAIL_INCLUDE }>,
  ) {
    const answerByItem = new Map(inspection.answers.map((a) => [a.itemId, a]));
    const riskByItem = new Map(inspection.riskAnswers.map((r) => [r.itemId, r]));
    return {
      id: inspection.id,
      code: qcReportCode(inspection),
      store: inspection.store,
      status: inspection.status,
      revision: inspection.revision,
      outcome: inspection.outcome,
      overallPercent: inspection.overallPercent,
      inspectionDate: inspection.inspectionDate.toISOString(),
      startedAt: inspection.startedAt?.toISOString() ?? null,
      endedAt: inspection.endedAt?.toISOString() ?? null,
      inspectorName: inspection.inspectorName,
      staffOnShift: inspection.staffOnShift,
      generalNotes: inspection.generalNotes,
      completedAt: inspection.completedAt?.toISOString() ?? null,
      sections: inspection.template.sections.map((s) => ({
        id: s.id,
        title: s.title,
        isRisk: s.isRisk,
        items: s.items.map((it, idx) => {
          const a = answerByItem.get(it.id);
          const r = riskByItem.get(it.id);
          return {
            id: it.id,
            no: idx + 1,
            sourceRef: it.sourceRef,
            text: it.text,
            ...(s.isRisk
              ? {
                  occurred: r?.occurred ?? null,
                  detail: r?.detail ?? null,
                  evidence: (r?.evidence ?? []).map((e) => ({ id: e.id, url: e.url })),
                }
              : {
                  value: a?.value ?? null,
                  failDetail: a?.failDetail ?? null,
                  naReason: a?.naReason ?? null,
                  evidence: (a?.evidence ?? []).map((e) => ({ id: e.id, url: e.url })),
                }),
          };
        }),
      })),
    };
  }
}

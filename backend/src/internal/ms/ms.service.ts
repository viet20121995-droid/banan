import { randomBytes } from 'node:crypto';

import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { removePrivateFile } from '../files/internal-files.util';
import { internalAppUrl, msReportRecipients } from '../internal-config';
import { InternalPdfService } from '../pdf/internal-pdf.service';

import type {
  CreateMsAssignmentDto,
  IssueTokenDto,
  MsListQueryDto,
  PublicSaveDto,
  RequestRevisionDto,
  UpdateMsAssignmentDto,
} from './dto';
import {
  MS_DETAIL_INCLUDE,
  buildMsReportBundle,
  loadMsReportBundle,
  type MsReportBundle,
} from './ms-report-data';
import { MS_TEMPLATE_NAME } from './ms-template-data';
import { generateMsToken, hashMsToken } from './ms-token.util';

const DEFAULT_TOKEN_TTL_DAYS = 14;
const MAX_TOKEN_TTL_DAYS = 60;

const EDITABLE_STATUSES = ['ASSIGNED', 'OPENED', 'NEEDS_REVISION'];

type TokenContext = Prisma.MsAccessTokenGetPayload<{
  include: { assignment: { include: typeof MS_DETAIL_INCLUDE } };
}>;

interface LockedAssignment {
  id: string;
  status: string;
}

@Injectable()
export class MsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly pdf: InternalPdfService,
  ) {}

  async activeTemplate() {
    const template = await this.prisma.msTemplate.findFirst({
      where: { name: MS_TEMPLATE_NAME, isActive: true },
      orderBy: { version: 'desc' },
      include: {
        sections: {
          orderBy: { sortOrder: 'asc' },
          include: { questions: { orderBy: { sortOrder: 'asc' } } },
        },
      },
    });
    if (!template) {
      throw new BadRequestException({
        code: 'INTERNAL_MS_NO_TEMPLATE',
        message: 'Chưa có mẫu Mystery Shopper. Chạy seed trước khi sử dụng.',
      });
    }
    return template;
  }

  // ── admin ─────────────────────────────────────────────────────────────────

  async create(dto: CreateMsAssignmentDto, actorId: string) {
    const store = await this.prisma.store.findUnique({ where: { id: dto.storeId } });
    if (!store) {
      throw new BadRequestException({
        code: 'INTERNAL_MS_STORE_NOT_FOUND',
        message: 'Chi nhánh không tồn tại.',
      });
    }
    const template = await this.activeTemplate();
    const assignment = await this.prisma.msAssignment.create({
      data: {
        code: await this.freshCode(),
        templateId: template.id,
        storeId: store.id,
        ...this.headerData(dto),
        createdById: actorId,
      },
      include: MS_DETAIL_INCLUDE,
    });
    return this.toAdminView(assignment);
  }

  async update(id: string, dto: UpdateMsAssignmentDto, actorId: string) {
    if (dto.storeId) {
      const store = await this.prisma.store.findUnique({ where: { id: dto.storeId } });
      if (!store) {
        throw new BadRequestException({
          code: 'INTERNAL_MS_STORE_NOT_FOUND',
          message: 'Chi nhánh không tồn tại.',
        });
      }
    }
    await this.prisma.$transaction(async (tx) => {
      const locked = await this.lockAssignment(tx, id);
      if (!['DRAFT', ...EDITABLE_STATUSES].includes(locked.status)) {
        throw new BadRequestException({
          code: 'INTERNAL_MS_LOCKED',
          message: 'Nhiệm vụ ở trạng thái này không sửa được.',
        });
      }
      if (dto.storeId && locked.status !== 'DRAFT') {
        const current = await tx.msAssignment.findUniqueOrThrow({
          where: { id },
          select: { storeId: true },
        });
        if (dto.storeId !== current.storeId) {
          throw new BadRequestException({
            code: 'INTERNAL_MS_STORE_LOCKED',
            message: 'Chỉ đổi chi nhánh khi nhiệm vụ còn nháp.',
          });
        }
      }
      await tx.msAssignment.update({
        where: { id },
        data: {
          ...(dto.storeId && locked.status === 'DRAFT' && { storeId: dto.storeId }),
          ...this.headerData(dto),
          updatedById: actorId,
        },
      });
    });
    return this.adminDetail(id);
  }

  async copy(id: string, actorId: string) {
    const src = await this.byId(id);
    const copy = await this.prisma.msAssignment.create({
      data: {
        code: await this.freshCode(),
        templateId: src.templateId,
        storeId: src.storeId,
        windowStart: src.windowStart,
        windowEnd: src.windowEnd,
        scenario: src.scenario,
        productsToBuy: src.productsToBuy,
        budgetVnd: src.budgetVnd,
        brief: src.brief,
        deadline: src.deadline,
        internalNotes: src.internalNotes,
        createdById: actorId,
      },
      include: MS_DETAIL_INCLUDE,
    });
    return this.toAdminView(copy);
  }

  async list(query: MsListQueryDto, page = 1, perPage = 30) {
    const where: Prisma.MsAssignmentWhereInput = {
      ...(query.storeId && { storeId: query.storeId }),
      ...(query.status && { status: query.status as never }),
      ...(query.outcome === 'CRITICAL_FAIL' && { submission: { is: { criticalFail: true } } }),
      ...(query.outcome === 'PASS' && {
        status: 'APPROVED' as const,
        submission: { is: { criticalFail: false } },
      }),
      ...((query.from || query.to) && {
        createdAt: {
          ...(query.from && { gte: new Date(query.from) }),
          ...(query.to && { lte: new Date(query.to) }),
        },
      }),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.msAssignment.findMany({
        where,
        include: {
          store: { select: { id: true, name: true } },
          submission: { select: { criticalFail: true, totalScore: true, submittedAt: true } },
          tokens: {
            where: { revokedAt: null },
            orderBy: { createdAt: 'desc' },
            take: 1,
            select: { expiresAt: true },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * perPage,
        take: perPage,
      }),
      this.prisma.msAssignment.count({ where }),
    ]);
    return {
      items: items.map((a) => ({
        id: a.id,
        code: a.code,
        store: a.store,
        status: this.effectiveStatus(a.status, a.tokens[0]?.expiresAt ?? null),
        windowStart: a.windowStart?.toISOString() ?? null,
        windowEnd: a.windowEnd?.toISOString() ?? null,
        deadline: a.deadline?.toISOString() ?? null,
        totalScore: a.submission?.totalScore ?? null,
        criticalFail: a.submission?.criticalFail ?? false,
        approvedRevision: a.approvedRevision,
        createdAt: a.createdAt.toISOString(),
      })),
      meta: { page, perPage, total },
    };
  }

  async adminDetail(id: string) {
    const assignment = await this.prisma.msAssignment.findUnique({
      where: { id },
      include: {
        ...MS_DETAIL_INCLUDE,
        tokens: { orderBy: { createdAt: 'desc' } },
      },
    });
    if (!assignment) this.notFound();
    return {
      ...this.toAdminView(assignment),
      // Token METADATA only — the raw token is never stored, never listed.
      tokens: assignment.tokens.map((t) => ({
        id: t.id,
        createdAt: t.createdAt.toISOString(),
        expiresAt: t.expiresAt.toISOString(),
        revokedAt: t.revokedAt?.toISOString() ?? null,
      })),
    };
  }

  /** Issues (or regenerates) the secret link. Old tokens are revoked; the
   *  RAW token appears exactly once — in this response. */
  async issueToken(id: string, dto: IssueTokenDto, actorId: string) {
    const assignment = await this.byId(id);
    if (['APPROVED', 'REVOKED'].includes(assignment.status)) {
      throw new BadRequestException({
        code: 'INTERNAL_MS_LOCKED',
        message: 'Nhiệm vụ đã kết thúc — không tạo link được.',
      });
    }
    const ttlDays = Math.min(dto.ttlDays ?? DEFAULT_TOKEN_TTL_DAYS, MAX_TOKEN_TTL_DAYS);
    const { raw, hash } = generateMsToken();
    const expiresAt = new Date(Date.now() + ttlDays * 86_400_000);
    await this.prisma.$transaction([
      this.prisma.msAccessToken.updateMany({
        where: { assignmentId: id, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
      this.prisma.msAccessToken.create({
        data: { assignmentId: id, tokenHash: hash, expiresAt, createdById: actorId },
      }),
      this.prisma.msAssignment.updateMany({
        where: { id, status: 'DRAFT' },
        data: { status: 'ASSIGNED' },
      }),
      // A fresh link also un-expires a lapsed assignment.
      this.prisma.msAssignment.updateMany({
        where: { id, status: 'EXPIRED' },
        data: { status: 'ASSIGNED' },
      }),
    ]);
    return {
      url: `${internalAppUrl(this.config)}/f/${raw}`,
      token: raw,
      expiresAt: expiresAt.toISOString(),
    };
  }

  /** Kills the whole mission: revokes tokens + status REVOKED. */
  async revoke(id: string, actorId: string) {
    await this.byId(id);
    await this.prisma.$transaction([
      this.prisma.msAccessToken.updateMany({
        where: { assignmentId: id, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
      this.prisma.msAssignment.update({
        where: { id },
        data: { status: 'REVOKED', updatedById: actorId },
      }),
    ]);
    return this.adminDetail(id);
  }

  async requestRevision(id: string, dto: RequestRevisionDto, actorId: string) {
    const claimed = await this.prisma.msAssignment.updateMany({
      where: { id, status: 'SUBMITTED' },
      data: { status: 'NEEDS_REVISION', revisionNote: dto.note.trim(), updatedById: actorId },
    });
    if (claimed.count === 0) {
      throw new BadRequestException({
        code: 'INTERNAL_MS_NOT_SUBMITTED',
        message: 'Chỉ yêu cầu bổ sung khi bài đã nộp.',
      });
    }
    return this.adminDetail(id);
  }

  /** Live score preview for the admin review screen. */
  async result(id: string) {
    const bundle = await loadMsReportBundle(this.prisma, id);
    return {
      outcome: bundle.result.outcome,
      totalScore: bundle.result.totalScore,
      criticalFail: bundle.result.criticalFail,
      sections: bundle.result.sections,
      issues: bundle.issues,
      criticals: bundle.criticalTexts,
    };
  }

  /**
   * Approves the submission. Row lock + load + score + status transition +
   * delivery all in ONE transaction — a shopper save racing this either
   * lands before the lock (and is scored) or is rejected afterwards, so the
   * stored snapshot always matches the answers it was computed from.
   */
  async approve(id: string, actorId: string): Promise<{ assignmentId: string; revision: number }> {
    const recipients = msReportRecipients(this.config);
    const revision = await this.prisma.$transaction(
      async (tx) => {
        const locked = await this.lockAssignment(tx, id);
        if (locked.status !== 'SUBMITTED') {
          throw new BadRequestException({
            code: 'INTERNAL_MS_NOT_SUBMITTED',
            message: 'Chỉ duyệt được bài đã nộp (chưa duyệt).',
          });
        }
        const assignment = await tx.msAssignment.findUniqueOrThrow({
          where: { id },
          include: MS_DETAIL_INCLUDE,
        });
        if (!assignment.submission) {
          throw new BadRequestException({
            code: 'INTERNAL_MS_NO_SUBMISSION',
            message: 'Chưa có bài nộp để duyệt.',
          });
        }
        const bundle = buildMsReportBundle(assignment);
        const claimed = await tx.msAssignment.updateMany({
          where: { id, status: 'SUBMITTED' },
          data: {
            status: 'APPROVED',
            approvedAt: new Date(),
            approvedById: actorId,
            approvedRevision: { increment: 1 },
            revisionNote: null,
          },
        });
        if (claimed.count === 0) {
          throw new BadRequestException({
            code: 'INTERNAL_MS_NOT_SUBMITTED',
            message: 'Chỉ duyệt được bài đã nộp (chưa duyệt).',
          });
        }
        const fresh = await tx.msAssignment.findUniqueOrThrow({
          where: { id },
          select: { approvedRevision: true },
        });
        await tx.msSubmission.update({
          where: { assignmentId: id },
          data: {
            criticalFail: bundle.result.criticalFail,
            totalScore: bundle.result.totalScore,
            sectionScores: bundle.result.sections as unknown as Prisma.InputJsonValue,
          },
        });
        // Bundle was built before the revision increment — stamp the final
        // revision, then freeze it as the delivery's immutable snapshot.
        bundle.revision = fresh.approvedRevision;
        bundle.pdf.revision = fresh.approvedRevision;
        // Audit PDF inside the lock, same contract as QcService.complete:
        // evidence removal needs this lock so every file is still on disk,
        // and a storage failure rolls the approval back entirely.
        const pdfFile = this.pdf.storeReportPdf(await this.pdf.renderMsReport(bundle.pdf));
        await tx.msReportDelivery.create({
          data: {
            assignmentId: id,
            revision: fresh.approvedRevision,
            recipients,
            reportSnapshot: bundle as unknown as Prisma.InputJsonValue,
            pdfFile,
          },
        });
        return fresh.approvedRevision;
      },
      { timeout: 15_000 },
    );
    return { assignmentId: id, revision };
  }

  reportBundle(id: string) {
    return loadMsReportBundle(this.prisma, id);
  }

  /** PDF download — mirrors QcService.downloadPdf: approved revisions come
   *  from the delivery row only; anything else is a watermarked draft. */
  async downloadPdf(id: string, revision?: number): Promise<{ bytes: Buffer; filename: string }> {
    const assignment = await this.prisma.msAssignment.findUnique({
      where: { id },
      select: { status: true, approvedRevision: true },
    });
    if (!assignment) this.notFound();
    const approvedRevision =
      revision ?? (assignment.status === 'APPROVED' ? assignment.approvedRevision : null);

    if (approvedRevision != null) {
      const delivery = await this.prisma.msReportDelivery.findUnique({
        where: { assignmentId_revision: { assignmentId: id, revision: approvedRevision } },
      });
      if (!delivery) {
        throw new NotFoundException({
          code: 'INTERNAL_MS_REPORT_NOT_FOUND',
          message: 'Không có báo cáo cho bản này.',
        });
      }
      const bundle = delivery.reportSnapshot as unknown as MsReportBundle;
      const bytes =
        this.pdf.readStoredPdf(delivery.pdfFile) ?? (await this.pdf.renderMsReport(bundle.pdf));
      return { bytes, filename: `${bundle.code}-r${delivery.revision}.pdf` };
    }

    const bundle = await this.reportBundle(id);
    const bytes = await this.pdf.renderMsReport(bundle.pdf, {
      watermark: 'BẢN NHÁP — CHƯA DUYỆT',
    });
    return { bytes, filename: `${bundle.code}-nhap.pdf` };
  }

  // ── public (token) ────────────────────────────────────────────────────────

  /** Resolves a raw token to its assignment, enforcing every gate. */
  private async resolveToken(raw: string): Promise<TokenContext> {
    const token = await this.prisma.msAccessToken.findUnique({
      where: { tokenHash: hashMsToken(raw) },
      include: { assignment: { include: MS_DETAIL_INCLUDE } },
    });
    if (!token) {
      throw new NotFoundException({
        code: 'INTERNAL_MS_LINK_INVALID',
        message: 'Link không hợp lệ.',
      });
    }
    if (token.revokedAt || token.assignment.status === 'REVOKED') {
      throw new BadRequestException({
        code: 'INTERNAL_MS_LINK_REVOKED',
        message: 'Link đã bị thu hồi.',
      });
    }
    if (token.expiresAt < new Date()) {
      // Lazily mark a lapsed assignment EXPIRED (only from live states).
      await this.prisma.msAssignment.updateMany({
        where: { id: token.assignmentId, status: { in: ['ASSIGNED', 'OPENED'] } },
        data: { status: 'EXPIRED' },
      });
      throw new BadRequestException({
        code: 'INTERNAL_MS_LINK_EXPIRED',
        message: 'Link đã hết hạn.',
      });
    }
    return token;
  }

  async publicView(rawToken: string) {
    const token = await this.resolveToken(rawToken);
    let assignment = token.assignment;
    if (assignment.status === 'ASSIGNED') {
      await this.prisma.msAssignment.update({
        where: { id: assignment.id },
        data: { status: 'OPENED', firstOpenedAt: assignment.firstOpenedAt ?? new Date() },
      });
      assignment = (await this.prisma.msAssignment.findUniqueOrThrow({
        where: { id: assignment.id },
        include: MS_DETAIL_INCLUDE,
      })) as TokenContext['assignment'];
    }
    return this.toPublicView(assignment);
  }

  async publicSave(dto: PublicSaveDto) {
    const token = await this.resolveToken(dto.token);
    const assignment = token.assignment;
    this.assertEditable(assignment.status);

    const questionIds = new Set(
      assignment.template.sections.flatMap((s) => s.questions.map((q) => q.id)),
    );
    for (const a of dto.answers ?? []) {
      if (!questionIds.has(a.questionId)) {
        throw new BadRequestException({
          code: 'INTERNAL_MS_QUESTION_MISMATCH',
          message: 'Câu hỏi không thuộc nhiệm vụ này.',
        });
      }
    }

    await this.prisma.$transaction(async (tx) => {
      const locked = await this.lockAssignment(tx, assignment.id);
      // Re-check under the lock — a submit/approve may have won the race.
      this.assertEditable(locked.status);
      const submission = await tx.msSubmission.upsert({
        where: { assignmentId: assignment.id },
        create: { assignmentId: assignment.id },
        update: {},
      });
      await tx.msSubmission.update({
        where: { id: submission.id },
        data: {
          ...(dto.enteredAt !== undefined && { enteredAt: this.date(dto.enteredAt) }),
          ...(dto.greetedAt !== undefined && { greetedAt: this.date(dto.greetedAt) }),
          ...(dto.orderStartAt !== undefined && { orderStartAt: this.date(dto.orderStartAt) }),
          ...(dto.paidAt !== undefined && { paidAt: this.date(dto.paidAt) }),
          ...(dto.receivedAt !== undefined && { receivedAt: this.date(dto.receivedAt) }),
          ...(dto.productsBought !== undefined && { productsBought: dto.productsBought || null }),
          ...(dto.amountPaidVnd !== undefined && { amountPaidVnd: dto.amountPaidVnd }),
          ...(dto.staffName !== undefined && { staffName: dto.staffName || null }),
          ...(dto.overallComment !== undefined && { overallComment: dto.overallComment || null }),
        },
      });
      for (const a of dto.answers ?? []) {
        await tx.msAnswer.upsert({
          where: {
            submissionId_questionId: { submissionId: submission.id, questionId: a.questionId },
          },
          create: {
            submissionId: submission.id,
            questionId: a.questionId,
            value: a.value ?? null,
            note: a.note?.trim() || null,
          },
          update: { value: a.value ?? null, note: a.note?.trim() || null },
        });
      }
    });
    return this.publicView(dto.token);
  }

  /** Records one uploaded PRIVATE evidence file against the submission. */
  async publicAttachEvidence(args: {
    rawToken: string;
    kind: 'RECEIPT' | 'PRODUCT' | 'PACKAGING' | 'ANSWER' | 'OTHER';
    questionId?: string;
    name: string;
    mimeType: string;
    sizeBytes: number;
  }) {
    const token = await this.resolveToken(args.rawToken);
    const assignment = token.assignment;
    this.assertEditable(assignment.status);
    await this.prisma.$transaction(async (tx) => {
      const locked = await this.lockAssignment(tx, assignment.id);
      this.assertEditable(locked.status);
      const submission = await tx.msSubmission.upsert({
        where: { assignmentId: assignment.id },
        create: { assignmentId: assignment.id },
        update: {},
      });
      let answerId: string | null = null;
      if (args.questionId) {
        const answer = await tx.msAnswer.upsert({
          where: {
            submissionId_questionId: {
              submissionId: submission.id,
              questionId: args.questionId,
            },
          },
          create: { submissionId: submission.id, questionId: args.questionId },
          update: {},
        });
        answerId = answer.id;
      }
      await tx.msEvidence.create({
        data: {
          submissionId: submission.id,
          answerId,
          kind: args.kind,
          url: args.name,
          mimeType: args.mimeType,
          sizeBytes: args.sizeBytes,
        },
      });
    });
    return this.publicView(args.rawToken);
  }

  async publicRemoveEvidence(rawToken: string, evidenceId: string) {
    const token = await this.resolveToken(rawToken);
    this.assertEditable(token.assignment.status);
    const fileName = await this.prisma.$transaction(async (tx) => {
      const locked = await this.lockAssignment(tx, token.assignmentId);
      this.assertEditable(locked.status);
      const ev = await tx.msEvidence.findUnique({
        where: { id: evidenceId },
        include: { submission: { select: { assignmentId: true } } },
      });
      if (!ev || ev.submission.assignmentId !== token.assignmentId) {
        throw new NotFoundException({
          code: 'INTERNAL_MS_EVIDENCE_NOT_FOUND',
          message: 'Không tìm thấy ảnh.',
        });
      }
      await tx.msEvidence.delete({ where: { id: ev.id } });
      return ev.url;
    });
    // Only after the DB row is gone — a failed tx must not lose the file.
    removePrivateFile(fileName);
    return this.publicView(rawToken);
  }

  /** Token-guarded evidence read: returns the private file name + mime only
   *  when that file belongs to THIS assignment's submission. */
  async publicEvidenceFile(
    rawToken: string,
    name: string,
  ): Promise<{ name: string; mimeType: string }> {
    const token = await this.resolveToken(rawToken);
    const ev = await this.prisma.msEvidence.findFirst({
      where: { url: name, submission: { assignmentId: token.assignmentId } },
      select: { url: true, mimeType: true },
    });
    if (!ev) {
      throw new NotFoundException({
        code: 'INTERNAL_MS_EVIDENCE_NOT_FOUND',
        message: 'Không tìm thấy ảnh.',
      });
    }
    return { name: ev.url, mimeType: ev.mimeType };
  }

  async publicSubmit(rawToken: string) {
    const token = await this.resolveToken(rawToken);
    const assignment = token.assignment;
    // Idempotent double-submit: the second call is a no-op success.
    if (assignment.status === 'SUBMITTED') return this.toPublicView(assignment);
    this.assertEditable(assignment.status);

    await this.prisma.$transaction(
      async (tx) => {
        const locked = await this.lockAssignment(tx, assignment.id);
        if (locked.status === 'SUBMITTED') return; // raced another submit — idempotent
        this.assertEditable(locked.status);
        // Re-load under the lock so validation sees the final answers.
        const fresh = await tx.msAssignment.findUniqueOrThrow({
          where: { id: assignment.id },
          include: MS_DETAIL_INCLUDE,
        });
        const submission = fresh.submission;
        const problems: { questionId: string | null; message: string }[] = [];
        const answerByQuestion = new Map((submission?.answers ?? []).map((a) => [a.questionId, a]));

        for (const section of fresh.template.sections) {
          for (const q of section.questions) {
            const a = answerByQuestion.get(q.id);
            if (section.kind === 'CRITICAL') {
              if (a?.value !== 'YES' && a?.value !== 'NO') {
                problems.push({ questionId: q.id, message: `Chưa trả lời: ${q.text}` });
              } else if (a.value === 'YES' && !a.note?.trim()) {
                problems.push({
                  questionId: q.id,
                  message: `Cần mô tả lỗi nghiêm trọng: ${q.text}`,
                });
              }
              continue;
            }
            if (!a?.value) {
              problems.push({ questionId: q.id, message: `Chưa trả lời: ${q.text}` });
            } else if (a.value === 'NOT_AVAILABLE') {
              if (!q.allowNa) {
                problems.push({
                  questionId: q.id,
                  message: `Câu này không được chọn N/A: ${q.text}`,
                });
              } else if (!a.note?.trim()) {
                problems.push({ questionId: q.id, message: `Chọn N/A phải ghi lý do: ${q.text}` });
              }
            }
          }
        }
        const receipts = (submission?.evidence ?? []).filter((e) => e.kind === 'RECEIPT');
        if (receipts.length === 0) {
          problems.push({ questionId: null, message: 'Bắt buộc tải ảnh hóa đơn.' });
        }
        const productShots = (submission?.evidence ?? []).filter((e) => e.kind === 'PRODUCT');
        if (productShots.length === 0) {
          problems.push({ questionId: null, message: 'Bắt buộc tải ảnh sản phẩm.' });
        }
        if (problems.length > 0) {
          throw new BadRequestException({
            code: 'INTERNAL_MS_INCOMPLETE',
            message: 'Chưa thể gửi — còn mục chưa hợp lệ.',
            details: problems,
          });
        }

        await tx.msSubmission.update({
          where: { assignmentId: assignment.id },
          data: { submittedAt: new Date() },
        });
        await tx.msAssignment.updateMany({
          where: { id: assignment.id, status: { in: ['OPENED', 'NEEDS_REVISION'] } },
          data: { status: 'SUBMITTED' },
        });
      },
      { timeout: 15_000 },
    );
    return this.publicView(rawToken);
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /** Locks the assignment row FOR UPDATE — save/submit/approve serialise. */
  private async lockAssignment(
    tx: Prisma.TransactionClient,
    id: string,
  ): Promise<LockedAssignment> {
    const rows = await tx.$queryRaw<LockedAssignment[]>`
      SELECT id, status FROM "MsAssignment" WHERE id = ${id} FOR UPDATE`;
    if (rows.length === 0) this.notFound();
    return rows[0];
  }

  private assertEditable(status: string): void {
    if (!EDITABLE_STATUSES.includes(status)) {
      throw new BadRequestException({
        code: 'INTERNAL_MS_NOT_EDITABLE',
        message:
          status === 'SUBMITTED'
            ? 'Bài đã nộp — chỉ bổ sung được khi quản trị viên yêu cầu.'
            : 'Nhiệm vụ không còn nhận bài.',
      });
    }
  }

  private date(v: string | undefined): Date | null {
    return v ? new Date(v) : null;
  }

  private headerData(dto: CreateMsAssignmentDto) {
    return {
      ...(dto.windowStart !== undefined && { windowStart: this.date(dto.windowStart) }),
      ...(dto.windowEnd !== undefined && { windowEnd: this.date(dto.windowEnd) }),
      ...(dto.scenario !== undefined && { scenario: dto.scenario?.trim() || null }),
      ...(dto.productsToBuy !== undefined && { productsToBuy: dto.productsToBuy?.trim() || null }),
      ...(dto.budgetVnd !== undefined && { budgetVnd: dto.budgetVnd }),
      ...(dto.brief !== undefined && { brief: dto.brief?.trim() || null }),
      ...(dto.deadline !== undefined && { deadline: this.date(dto.deadline) }),
      ...(dto.internalNotes !== undefined && { internalNotes: dto.internalNotes?.trim() || null }),
    };
  }

  private async freshCode(): Promise<string> {
    for (let i = 0; i < 5; i++) {
      const code = `MS-${new Date().getFullYear()}-${randomBytes(4)
        .toString('base64url')
        .replace(/[^a-zA-Z0-9]/g, '')
        .slice(0, 5)
        .toUpperCase()}`;
      const clash = await this.prisma.msAssignment.findUnique({ where: { code } });
      if (!clash && code.length === 13) return code;
    }
    return `MS-${Date.now().toString(36).toUpperCase()}`;
  }

  private effectiveStatus(status: string, activeTokenExpiry: Date | null): string {
    if (
      ['ASSIGNED', 'OPENED'].includes(status) &&
      activeTokenExpiry &&
      activeTokenExpiry < new Date()
    ) {
      return 'EXPIRED';
    }
    return status;
  }

  private async byId(id: string) {
    const assignment = await this.prisma.msAssignment.findUnique({
      where: { id },
      include: MS_DETAIL_INCLUDE,
    });
    if (!assignment) this.notFound();
    return assignment;
  }

  private notFound(): never {
    throw new NotFoundException({
      code: 'INTERNAL_MS_NOT_FOUND',
      message: 'Không tìm thấy nhiệm vụ.',
    });
  }

  private toAdminView(a: Prisma.MsAssignmentGetPayload<{ include: typeof MS_DETAIL_INCLUDE }>) {
    return {
      id: a.id,
      code: a.code,
      store: a.store,
      status: a.status,
      windowStart: a.windowStart?.toISOString() ?? null,
      windowEnd: a.windowEnd?.toISOString() ?? null,
      scenario: a.scenario,
      productsToBuy: a.productsToBuy,
      budgetVnd: a.budgetVnd,
      brief: a.brief,
      deadline: a.deadline?.toISOString() ?? null,
      internalNotes: a.internalNotes,
      revisionNote: a.revisionNote,
      firstOpenedAt: a.firstOpenedAt?.toISOString() ?? null,
      approvedRevision: a.approvedRevision,
      approvedAt: a.approvedAt?.toISOString() ?? null,
      createdAt: a.createdAt.toISOString(),
      submission: this.submissionView(a),
      template: this.templateView(a),
    };
  }

  /** Public payload: brief only — NO internal notes, NO audit ids. */
  private toPublicView(a: Prisma.MsAssignmentGetPayload<{ include: typeof MS_DETAIL_INCLUDE }>) {
    return {
      code: a.code,
      storeName: a.store.name,
      status: a.status,
      windowStart: a.windowStart?.toISOString() ?? null,
      windowEnd: a.windowEnd?.toISOString() ?? null,
      scenario: a.scenario,
      productsToBuy: a.productsToBuy,
      budgetVnd: a.budgetVnd,
      brief: a.brief,
      deadline: a.deadline?.toISOString() ?? null,
      revisionNote: a.status === 'NEEDS_REVISION' ? a.revisionNote : null,
      submission: this.submissionView(a),
      template: this.templateView(a),
    };
  }

  private templateView(a: Prisma.MsAssignmentGetPayload<{ include: typeof MS_DETAIL_INCLUDE }>) {
    return {
      sections: a.template.sections.map((s) => ({
        id: s.id,
        code: s.code,
        title: s.title,
        kind: s.kind,
        weight: s.weight,
        questions: s.questions.map((q) => ({ id: q.id, text: q.text, allowNa: q.allowNa })),
      })),
    };
  }

  private submissionView(a: Prisma.MsAssignmentGetPayload<{ include: typeof MS_DETAIL_INCLUDE }>) {
    const s = a.submission;
    if (!s) return null;
    return {
      submittedAt: s.submittedAt?.toISOString() ?? null,
      enteredAt: s.enteredAt?.toISOString() ?? null,
      greetedAt: s.greetedAt?.toISOString() ?? null,
      orderStartAt: s.orderStartAt?.toISOString() ?? null,
      paidAt: s.paidAt?.toISOString() ?? null,
      receivedAt: s.receivedAt?.toISOString() ?? null,
      productsBought: s.productsBought,
      amountPaidVnd: s.amountPaidVnd,
      staffName: s.staffName,
      overallComment: s.overallComment,
      criticalFail: s.criticalFail,
      totalScore: s.totalScore,
      answers: s.answers.map((ans) => ({
        questionId: ans.questionId,
        value: ans.value,
        note: ans.note,
        evidence: ans.evidence.map((e) => ({ id: e.id, url: e.url, kind: e.kind })),
      })),
      evidence: s.evidence
        .filter((e) => e.answerId == null)
        .map((e) => ({ id: e.id, url: e.url, kind: e.kind })),
    };
  }
}

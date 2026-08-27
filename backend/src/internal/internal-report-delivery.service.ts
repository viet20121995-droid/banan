import { randomUUID } from 'node:crypto';

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';

import { EmailService } from '../notifications/email.service';
import { PrismaService } from '../prisma/prisma.service';

import { internalAppUrl } from './internal-config';
import { InternalPdfService } from './pdf/internal-pdf.service';
import type { MsReportBundle } from './ms/ms-report-data';
import type { QcReportBundle } from './qc/qc-report-data';

const MAX_ATTEMPTS = 5;
/** A claim older than this is presumed dead and may be stolen by the cron. */
const CLAIM_TTL_MS = 10 * 60_000;

interface DeliveryRow {
  id: string;
  revision: number;
  recipients: string[];
  status: string;
  attempts: number;
  lockedUntil: Date | null;
}

/**
 * Outbox for QC / MS report emails. A delivery row is created inside the
 * complete/approve transaction (unique on (parent, revision) — the
 * idempotency marker), then dispatched fire-and-forget here; an email/SMTP
 * failure can therefore never roll back a saved result.
 *
 * Every email/PDF is rendered from the row's immutable `reportSnapshot`
 * (frozen at complete/approve time) — NEVER from the live inspection — so a
 * retried r1 delivery can never carry r2 data.
 *
 * All public entry points swallow their own errors (log + FAILED marking):
 * they are called fire-and-forget (`void dispatch…`) and from cron, where an
 * escaped rejection would crash the process.
 *
 * Concurrency: a dispatcher CLAIMS the row by flipping it to PROCESSING with
 * a fresh `claimToken` + `lockedUntil` — the status flip excludes every other
 * dispatcher outright (not just ones holding the same snapshot). markResult
 * is guarded on the claimToken, so a worker whose expired claim was stolen
 * by the cron can no longer write the outcome. Residual duplicate window:
 * only a worker that stalls past CLAIM_TTL and STILL manages to send —
 * accepted at-least-once behaviour.
 */
@Injectable()
export class InternalReportDeliveryService {
  private readonly logger = new Logger(InternalReportDeliveryService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly email: EmailService,
    private readonly pdf: InternalPdfService,
    private readonly config: ConfigService,
  ) {}

  /** Retry loop: unsent rows under the attempt cap — PENDING/FAILED older
   *  than 2 min (the inline dispatch owns the first window), plus PROCESSING
   *  rows whose claim expired (worker died mid-send). */
  @Cron(CronExpression.EVERY_10_MINUTES)
  async retryPending(): Promise<void> {
    try {
      const now = new Date();
      const staleCreated = new Date(now.getTime() - 2 * 60_000);
      const where = {
        attempts: { lt: MAX_ATTEMPTS },
        OR: [
          { status: { in: ['PENDING', 'FAILED'] as never[] }, createdAt: { lt: staleCreated } },
          { status: 'PROCESSING' as never, lockedUntil: { lt: now } },
        ],
      };
      const [qc, ms] = await Promise.all([
        this.prisma.qcReportDelivery.findMany({ where, select: { id: true }, take: 20 }),
        this.prisma.msReportDelivery.findMany({ where, select: { id: true }, take: 20 }),
      ]);
      for (const d of qc) await this.dispatchQcById(d.id);
      for (const d of ms) await this.dispatchMsById(d.id);
    } catch (err) {
      this.logger.error(`Delivery retry sweep failed: ${(err as Error).message}`);
    }
  }

  /** Called (fire-and-forget) right after a successful QC complete. NEVER
   *  rejects — an escaped rejection from a `void` call would kill the process. */
  async dispatchQc(inspectionId: string, revision: number): Promise<void> {
    try {
      const delivery = await this.prisma.qcReportDelivery.findUnique({
        where: { inspectionId_revision: { inspectionId, revision } },
        select: { id: true },
      });
      if (delivery) await this.dispatchQcById(delivery.id);
    } catch (err) {
      this.logger.error(`QC dispatch ${inspectionId} r${revision}: ${(err as Error).message}`);
    }
  }

  async dispatchMs(assignmentId: string, revision: number): Promise<void> {
    try {
      const delivery = await this.prisma.msReportDelivery.findUnique({
        where: { assignmentId_revision: { assignmentId, revision } },
        select: { id: true },
      });
      if (delivery) await this.dispatchMsById(delivery.id);
    } catch (err) {
      this.logger.error(`MS dispatch ${assignmentId} r${revision}: ${(err as Error).message}`);
    }
  }

  /**
   * Exclusive claim. Open rows (PENDING/FAILED) are taken by the status
   * flip alone; an expired PROCESSING row is stolen with a CAS on its old
   * `lockedUntil` so exactly one thief wins. Returns the claim token, or
   * null when someone else owns the row.
   */
  private async claim(
    table: {
      updateMany: (args: {
        where: Record<string, unknown>;
        data: Record<string, unknown>;
      }) => Promise<{ count: number }>;
    },
    row: DeliveryRow,
  ): Promise<string | null> {
    const token = randomUUID();
    const data = {
      status: 'PROCESSING',
      claimToken: token,
      lockedUntil: new Date(Date.now() + CLAIM_TTL_MS),
      attempts: { increment: 1 },
    };
    const where =
      row.status === 'PROCESSING'
        ? // Steal only an EXPIRED claim, CAS'd on the exact lockedUntil we saw.
          { id: row.id, status: 'PROCESSING', lockedUntil: row.lockedUntil ?? new Date(0) }
        : { id: row.id, status: { in: ['PENDING', 'FAILED'] } };
    if (row.status === 'PROCESSING' && row.lockedUntil && row.lockedUntil >= new Date()) {
      return null; // live claim — not ours to touch
    }
    const claimed = await table.updateMany({ where, data });
    return claimed.count === 1 ? token : null;
  }

  private async dispatchQcById(deliveryId: string): Promise<void> {
    let token: string | null = null;
    try {
      const delivery = await this.prisma.qcReportDelivery.findUnique({ where: { id: deliveryId } });
      if (!delivery || delivery.status === 'SENT' || delivery.attempts >= MAX_ATTEMPTS) return;
      token = await this.claim(this.prisma.qcReportDelivery, delivery);
      if (!token) return;

      // Immutable snapshot frozen at complete() — the live inspection may
      // already be at a later revision. Attach the PDF stored at completion
      // (immune to evidence files deleted since); re-render from the
      // snapshot only when that file is missing.
      const bundle = delivery.reportSnapshot as unknown as QcReportBundle;
      const pdfBytes =
        this.pdf.readStoredPdf(delivery.pdfFile) ?? (await this.pdf.renderQcReport(bundle.pdf));
      const outcomeLabel =
        bundle.result.outcome === 'PASS'
          ? 'ĐẠT'
          : bundle.result.outcome === 'FAIL'
            ? 'KHÔNG ĐẠT'
            : 'CRITICAL FAIL';
      const updated = delivery.revision > 1;
      const subject = `${updated ? 'Kết quả QC đã cập nhật · ' : ''}[QC] ${outcomeLabel} · ${bundle.storeName} · ${bundle.inspectionDateLabel}`;

      const lines = [
        `Chi nhánh: ${bundle.storeName}`,
        `Ngày kiểm tra: ${bundle.inspectionDateLabel}`,
        `Người kiểm tra: ${bundle.inspectorName}`,
        `Kết quả: ${outcomeLabel}${updated ? ` (bản cập nhật số ${delivery.revision})` : ''}`,
        `Tổng điểm: ${
          bundle.result.overallPercent == null
            ? 'N/A'
            : `${bundle.result.overallPass}/${bundle.result.overallApplicable} · ${bundle.result.overallPercent}%`
        }`,
        ...bundle.result.sections.map(
          (s) =>
            `${s.title}: ${s.percent == null ? 'N/A' : `${s.passCount}/${s.applicable} · ${s.percent}%`}`,
        ),
        ...(bundle.occurredRisks.length > 0
          ? ['RISK XẢY RA:', ...bundle.occurredRisks.map((r) => `⚠ ${r}`)]
          : ['Risk: không có']),
        ...(bundle.failedItems.length > 0
          ? [
              'Tiêu chí không đạt:',
              ...bundle.failedItems.map(
                (f) => `• [${f.section}] ${f.text}${f.detail ? ` — ${f.detail}` : ''}`,
              ),
            ]
          : []),
      ];

      const ok = await this.email.sendInternalReport({
        to: delivery.recipients,
        subject,
        heading: updated ? 'Kết quả QC đã cập nhật' : 'Báo cáo kiểm tra QC',
        lines,
        ctaUrl: `${internalAppUrl(this.config)}/qc/${delivery.inspectionId}`,
        ctaLabel: 'Xem kết quả QC',
        attachment: { filename: `${bundle.code}-r${delivery.revision}.pdf`, content: pdfBytes },
      });
      await this.markResult(this.prisma.qcReportDelivery, deliveryId, token, ok);
    } catch (err) {
      this.logger.error(`QC delivery ${deliveryId} failed: ${(err as Error).message}`);
      try {
        if (token) {
          await this.markResult(
            this.prisma.qcReportDelivery,
            deliveryId,
            token,
            false,
            (err as Error).message,
          );
        }
      } catch (markErr) {
        this.logger.error(
          `QC delivery ${deliveryId} FAILED-mark failed: ${(markErr as Error).message}`,
        );
      }
    }
  }

  private async dispatchMsById(deliveryId: string): Promise<void> {
    let token: string | null = null;
    try {
      const delivery = await this.prisma.msReportDelivery.findUnique({ where: { id: deliveryId } });
      if (!delivery || delivery.status === 'SENT' || delivery.attempts >= MAX_ATTEMPTS) return;
      token = await this.claim(this.prisma.msReportDelivery, delivery);
      if (!token) return;

      // Immutable snapshot frozen at approve() — never the live assignment.
      // Stored approval-time PDF first, snapshot render as fallback.
      const bundle = delivery.reportSnapshot as unknown as MsReportBundle;
      const pdfBytes =
        this.pdf.readStoredPdf(delivery.pdfFile) ?? (await this.pdf.renderMsReport(bundle.pdf));
      const outcomeLabel = bundle.result.criticalFail
        ? 'CRITICAL FAIL'
        : `${bundle.result.totalScore ?? 'N/A'}/100`;
      const updated = delivery.revision > 1;
      const subject = `${updated ? 'Kết quả Mystery Shopper đã cập nhật · ' : ''}[MS] ${outcomeLabel} · ${bundle.storeName} · ${bundle.performedDateLabel}`;

      const lines = [
        `Mã nhiệm vụ: ${bundle.code}`,
        `Chi nhánh: ${bundle.storeName}`,
        `Ngày thực hiện: ${bundle.performedDateLabel}`,
        `Điểm tổng: ${bundle.result.totalScore == null ? 'N/A' : `${bundle.result.totalScore}/100`}`,
        ...bundle.result.sections.map(
          (s) => `${s.code}. ${s.title}: ${s.score == null ? 'N/A' : `${s.score}/${s.weight}`}`,
        ),
        ...(bundle.criticalTexts.length > 0
          ? ['LỖI NGHIÊM TRỌNG:', ...bundle.criticalTexts.map((c) => `⚠ ${c}`)]
          : ['Lỗi nghiêm trọng: không có']),
        ...bundle.timeline.map((t) => `${t.label}: ${t.value}`),
        ...(bundle.purchaseSummary ? [`Sản phẩm đã mua: ${bundle.purchaseSummary}`] : []),
        ...(bundle.issues.length > 0
          ? ['Vấn đề ghi nhận:', ...bundle.issues.map((i) => `• ${i}`)]
          : []),
        ...(bundle.overallComment ? [`Nhận xét: ${bundle.overallComment}`] : []),
      ];

      const ok = await this.email.sendInternalReport({
        to: delivery.recipients,
        subject,
        heading: updated ? 'Kết quả Mystery Shopper đã cập nhật' : 'Báo cáo Mystery Shopper',
        lines,
        ctaUrl: `${internalAppUrl(this.config)}/ms/${delivery.assignmentId}`,
        ctaLabel: 'Xem báo cáo MS',
        attachment: { filename: `${bundle.code}-r${delivery.revision}.pdf`, content: pdfBytes },
      });
      await this.markResult(this.prisma.msReportDelivery, deliveryId, token, ok);
    } catch (err) {
      this.logger.error(`MS delivery ${deliveryId} failed: ${(err as Error).message}`);
      try {
        if (token) {
          await this.markResult(
            this.prisma.msReportDelivery,
            deliveryId,
            token,
            false,
            (err as Error).message,
          );
        }
      } catch (markErr) {
        this.logger.error(
          `MS delivery ${deliveryId} FAILED-mark failed: ${(markErr as Error).message}`,
        );
      }
    }
  }

  /** Outcome write, guarded on OUR claim token — a stolen claim can't
   *  overwrite the thief's in-flight state. */
  private async markResult(
    table: {
      updateMany: (args: {
        where: Record<string, unknown>;
        data: Record<string, unknown>;
      }) => Promise<{ count: number }>;
    },
    id: string,
    claimToken: string,
    ok: boolean,
    error?: string,
  ): Promise<void> {
    const res = await table.updateMany({
      where: { id, claimToken, status: 'PROCESSING' },
      data: ok
        ? { status: 'SENT', sentAt: new Date(), lastError: null, lockedUntil: null }
        : {
            status: 'FAILED',
            lockedUntil: null,
            lastError: error ?? 'Email không được provider chấp nhận (dry-run hoặc lỗi gửi).',
          },
    });
    if (res.count === 0) {
      this.logger.warn(`Delivery ${id}: claim was superseded — result not recorded by this worker`);
    }
  }
}

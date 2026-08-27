import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';

import { Injectable, Logger } from '@nestjs/common';
import PDFDocument from 'pdfkit';

import {
  ensurePrivateDir,
  isPrivateFileName,
  privateFileName,
  privateFilePath,
} from '../files/internal-files.util';

/**
 * PDF rendering for the internal ops reports (QC + Mystery Shopper).
 *
 * - Be Vietnam Pro (regular + bold) is embedded from `backend/assets/fonts`
 *   so Vietnamese renders with correct diacritics — pdfkit's built-in
 *   Helvetica cannot.
 * - Evidence images are read back from the local `uploads/` disk (the same
 *   store the upload endpoint writes to); a missing file renders as a note
 *   instead of crashing the report.
 * - Summary page first, per-section detail after, footer with report code,
 *   revision and page numbers on every page.
 */

const FONT_REGULAR = join(process.cwd(), 'assets', 'fonts', 'BeVietnamPro-Regular.ttf');
const FONT_BOLD = join(process.cwd(), 'assets', 'fonts', 'BeVietnamPro-Bold.ttf');
const LOGO = join(process.cwd(), 'assets', 'brand', 'logo.png');

const GREEN = '#1E6A35';
const RED = '#C12B36';
const INK = '#26221D';
const MUTED = '#6B5A52';
const LINE = '#E0D7CC';

const PAGE_MARGIN = 48;

export interface PdfEvidenceRef {
  url: string;
  label?: string;
}

export interface QcPdfData {
  code: string;
  revision: number;
  storeName: string;
  inspectionDate: string;
  startedAt?: string;
  endedAt?: string;
  inspectorName: string;
  staffOnShift?: string;
  generalNotes?: string;
  outcome: 'PASS' | 'FAIL' | 'CRITICAL_FAIL';
  overallPercent: number | null;
  overallPass: number;
  overallApplicable: number;
  sections: {
    title: string;
    percent: number | null;
    passCount: number;
    applicable: number;
    naCount: number;
    items: {
      no: string;
      text: string;
      value: 'PASS' | 'FAIL' | 'NOT_AVAILABLE' | null;
      failDetail?: string;
      naReason?: string;
      evidence: PdfEvidenceRef[];
    }[];
  }[];
  risks: {
    text: string;
    occurred: boolean | null;
    detail?: string;
    evidence: PdfEvidenceRef[];
  }[];
}

export interface MsPdfData {
  code: string;
  revision: number;
  storeName: string;
  performedDate: string;
  outcome: 'PASS' | 'CRITICAL_FAIL';
  totalScore: number | null;
  criticalFail: boolean;
  timeline: { label: string; value: string }[];
  purchase: { label: string; value: string }[];
  sections: {
    code: string;
    title: string;
    weight: number;
    score: number | null;
    questions: {
      text: string;
      value: 'YES' | 'NO' | 'NOT_AVAILABLE' | null;
      note?: string;
      evidence: PdfEvidenceRef[];
    }[];
  }[];
  criticals: {
    text: string;
    occurred: boolean;
    note?: string;
    evidence: PdfEvidenceRef[];
  }[];
  overallComment?: string;
}

type Doc = typeof PDFDocument.prototype;

@Injectable()
export class InternalPdfService {
  private readonly logger = new Logger(InternalPdfService.name);

  /** Renders and returns the finished PDF bytes. A `watermark` marks a
   *  draft preview — NEVER pass one for an approved/completed report. */
  renderQcReport(data: QcPdfData, opts?: { watermark?: string }): Promise<Buffer> {
    return this.render(
      (doc) => {
        this.header(doc, 'BÁO CÁO KIỂM TRA QC', data.storeName, data.inspectionDate);

        // ── Summary ──
        const outcomeLabel =
          data.outcome === 'PASS'
            ? 'ĐẠT'
            : data.outcome === 'FAIL'
              ? 'KHÔNG ĐẠT'
              : 'KHÔNG ĐẠT — LỖI NGHIÊM TRỌNG (RISK)';
        this.badge(doc, outcomeLabel, data.outcome === 'PASS' ? GREEN : RED);
        doc.moveDown(0.6);

        this.kv(doc, [
          ['Mã báo cáo', `${data.code} · bản ${data.revision}`],
          ['Chi nhánh', data.storeName],
          ['Ngày kiểm tra', data.inspectionDate],
          ['Thời gian', [data.startedAt, data.endedAt].filter(Boolean).join(' – ') || '—'],
          ['Người kiểm tra', data.inspectorName],
          ['Nhân viên trong ca', data.staffOnShift || '—'],
          [
            'Điểm tổng',
            data.overallPercent == null
              ? 'N/A'
              : `${data.overallPass}/${data.overallApplicable} · ${data.overallPercent}%`,
          ],
        ]);
        doc.moveDown(0.8);

        // Section score table.
        this.sectionTitle(doc, 'Điểm theo hạng mục');
        for (const s of data.sections) {
          const label =
            s.percent == null ? 'N/A' : `${s.passCount}/${s.applicable} · ${s.percent}%`;
          const failed = s.percent != null && s.percent < 80;
          this.row2(doc, s.title, label, failed ? RED : INK);
        }
        doc.moveDown(0.5);

        // Risks summary.
        this.sectionTitle(doc, 'RISK');
        for (const r of data.risks) {
          this.row2(
            doc,
            r.text,
            r.occurred === true ? 'CÓ' : r.occurred === false ? 'Không' : '—',
            r.occurred === true ? RED : INK,
          );
        }
        if (data.generalNotes) {
          doc.moveDown(0.5);
          this.sectionTitle(doc, 'Ghi chú chung');
          doc.font(FONT_REGULAR).fontSize(10).fillColor(INK).text(data.generalNotes);
        }

        // ── Details ──
        doc.addPage();
        this.sectionTitle(doc, 'Chi tiết từng tiêu chí');
        for (const s of data.sections) {
          this.ensureRoom(doc, 60);
          doc.moveDown(0.4);
          doc.font(FONT_BOLD).fontSize(11).fillColor(GREEN).text(s.title);
          doc.moveDown(0.2);
          for (const it of s.items) {
            this.ensureRoom(doc, 40);
            const mark =
              it.value === 'PASS'
                ? 'Đạt'
                : it.value === 'FAIL'
                  ? 'KHÔNG ĐẠT'
                  : it.value === 'NOT_AVAILABLE'
                    ? 'N/A'
                    : '—';
            doc
              .font(FONT_REGULAR)
              .fontSize(9.5)
              .fillColor(it.value === 'FAIL' ? RED : INK)
              .text(`${it.no}. ${it.text} — ${mark}`, { width: this.contentWidth(doc) });
            if (it.failDetail) {
              doc.fillColor(RED).fontSize(9).text(`   Lỗi: ${it.failDetail}`);
            }
            if (it.naReason) {
              doc.fillColor(MUTED).fontSize(9).text(`   Lý do N/A: ${it.naReason}`);
            }
            this.images(doc, it.evidence);
          }
        }

        // Risk details with evidence.
        const occurredRisks = data.risks.filter((r) => r.occurred === true);
        if (occurredRisks.length > 0) {
          this.ensureRoom(doc, 80);
          doc.moveDown(0.6);
          doc.font(FONT_BOLD).fontSize(11).fillColor(RED).text('CHI TIẾT RISK');
          for (const r of occurredRisks) {
            this.ensureRoom(doc, 40);
            doc.font(FONT_REGULAR).fontSize(9.5).fillColor(RED).text(`• ${r.text}`);
            if (r.detail) doc.fillColor(INK).fontSize(9).text(`   ${r.detail}`);
            this.images(doc, r.evidence);
          }
        }
      },
      `${data.code} · bản ${data.revision}`,
      opts?.watermark,
    );
  }

  renderMsReport(data: MsPdfData, opts?: { watermark?: string }): Promise<Buffer> {
    return this.render(
      (doc) => {
        this.header(doc, 'BÁO CÁO MYSTERY SHOPPER', data.storeName, data.performedDate);

        const outcomeLabel = data.criticalFail
          ? 'LỖI NGHIÊM TRỌNG (CRITICAL FAIL)'
          : `${data.totalScore ?? 'N/A'}/100 điểm`;
        this.badge(doc, outcomeLabel, data.criticalFail ? RED : GREEN);
        doc.moveDown(0.6);

        this.kv(doc, [
          ['Mã nhiệm vụ', `${data.code} · bản ${data.revision}`],
          ['Chi nhánh', data.storeName],
          ['Ngày thực hiện', data.performedDate],
          ...data.purchase.map((p) => [p.label, p.value] as [string, string]),
        ]);
        doc.moveDown(0.6);

        this.sectionTitle(doc, 'Timeline phục vụ');
        for (const t of data.timeline) this.row2(doc, t.label, t.value, INK);
        doc.moveDown(0.6);

        this.sectionTitle(doc, 'Điểm theo nhóm');
        for (const s of data.sections) {
          this.row2(
            doc,
            `${s.code}. ${s.title}`,
            s.score == null ? 'N/A' : `${s.score}/${s.weight}`,
            INK,
          );
        }

        const occurred = data.criticals.filter((c) => c.occurred);
        if (occurred.length > 0) {
          doc.moveDown(0.6);
          this.sectionTitle(doc, 'Lỗi nghiêm trọng');
          for (const c of occurred) {
            doc.font(FONT_REGULAR).fontSize(10).fillColor(RED).text(`• ${c.text}`);
            if (c.note) doc.fillColor(INK).fontSize(9).text(`   ${c.note}`);
          }
        }

        if (data.overallComment) {
          doc.moveDown(0.6);
          this.sectionTitle(doc, 'Nhận xét tổng quan');
          doc.font(FONT_REGULAR).fontSize(10).fillColor(INK).text(data.overallComment);
        }

        // ── Details ──
        doc.addPage();
        this.sectionTitle(doc, 'Chi tiết từng câu');
        for (const s of data.sections) {
          this.ensureRoom(doc, 60);
          doc.moveDown(0.4);
          doc
            .font(FONT_BOLD)
            .fontSize(11)
            .fillColor(GREEN)
            .text(`${s.code}. ${s.title} (${s.score == null ? 'N/A' : `${s.score}/${s.weight}`})`);
          doc.moveDown(0.2);
          s.questions.forEach((q, i) => {
            this.ensureRoom(doc, 40);
            const mark =
              q.value === 'YES'
                ? 'Đạt'
                : q.value === 'NO'
                  ? 'KHÔNG ĐẠT'
                  : q.value === 'NOT_AVAILABLE'
                    ? 'N/A'
                    : '—';
            doc
              .font(FONT_REGULAR)
              .fontSize(9.5)
              .fillColor(q.value === 'NO' ? RED : INK)
              .text(`${i + 1}. ${q.text} — ${mark}`, { width: this.contentWidth(doc) });
            if (q.note) doc.fillColor(MUTED).fontSize(9).text(`   ${q.note}`);
            this.images(doc, q.evidence);
          });
        }

        for (const c of data.criticals.filter((x) => x.occurred)) {
          this.ensureRoom(doc, 60);
          doc.moveDown(0.4);
          doc.font(FONT_BOLD).fontSize(11).fillColor(RED).text('Bằng chứng lỗi nghiêm trọng');
          doc.font(FONT_REGULAR).fontSize(9.5).fillColor(RED).text(`• ${c.text}`);
          this.images(doc, c.evidence);
        }
      },
      `${data.code} · bản ${data.revision}`,
      opts?.watermark,
    );
  }

  /** Persists finished report bytes into the private store and returns the
   *  generated name. THROWS on failure — complete/approve call this inside
   *  their locked transaction, because a result may only be published once
   *  its audit PDF exists. A file written before a rollback is an orphan the
   *  daily sweep removes. */
  storeReportPdf(bytes: Buffer): string {
    const name = privateFileName('application/pdf');
    writeFileSync(join(ensurePrivateDir(), name), bytes);
    return name;
  }

  /** Reads a stored report PDF back; null when absent/unreadable so the
   *  caller can fall back to rendering from the snapshot. */
  readStoredPdf(name: string | null | undefined): Buffer | null {
    if (!name || !isPrivateFileName(name)) return null;
    try {
      return readFileSync(privateFilePath(name));
    } catch {
      return null;
    }
  }

  // ── plumbing ──────────────────────────────────────────────────────────────

  private render(
    body: (doc: Doc) => void,
    footerCode: string,
    watermark?: string,
  ): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({
        size: 'A4',
        margins: {
          top: PAGE_MARGIN,
          bottom: PAGE_MARGIN + 16,
          left: PAGE_MARGIN,
          right: PAGE_MARGIN,
        },
        bufferPages: true,
        info: { Title: footerCode, Author: 'Banan Fukuoka Saigon' },
      });
      const chunks: Buffer[] = [];
      doc.on('data', (c: Buffer) => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      doc.registerFont('viet', FONT_REGULAR);
      doc.registerFont('viet-bold', FONT_BOLD);
      doc.font(FONT_REGULAR);

      body(doc);

      // Footer on every page (buffered). The write sits BELOW the content
      // area, so the bottom margin must be zeroed per page first — otherwise
      // pdfkit "helpfully" opens a fresh page for each footer line.
      const range = doc.bufferedPageRange();
      for (let i = range.start; i < range.start + range.count; i++) {
        doc.switchToPage(i);
        doc.page.margins.bottom = 0;
        if (watermark) {
          // Diagonal draft stamp across every page — unmissable on screen
          // and on paper, so a preview can never pass as the approved report.
          doc
            .save()
            .rotate(-38, { origin: [doc.page.width / 2, doc.page.height / 2] })
            .font(FONT_BOLD)
            .fontSize(42)
            .fillColor(RED)
            .fillOpacity(0.14)
            .text(watermark, 0, doc.page.height / 2 - 24, {
              width: doc.page.width,
              align: 'center',
              lineBreak: false,
            })
            .restore();
        }
        const y = doc.page.height - PAGE_MARGIN + 2;
        doc
          .font(FONT_REGULAR)
          .fontSize(8)
          .fillColor(MUTED)
          .text(footerCode, PAGE_MARGIN, y, { lineBreak: false })
          .text(`Trang ${i - range.start + 1}/${range.count}`, PAGE_MARGIN, y, {
            width: doc.page.width - PAGE_MARGIN * 2,
            align: 'right',
            lineBreak: false,
          });
      }
      doc.end();
    });
  }

  private contentWidth(doc: Doc): number {
    return doc.page.width - PAGE_MARGIN * 2;
  }

  private ensureRoom(doc: Doc, needed: number): void {
    if (doc.y + needed > doc.page.height - PAGE_MARGIN - 24) doc.addPage();
  }

  private header(doc: Doc, title: string, store: string, date: string): void {
    if (existsSync(LOGO)) {
      try {
        doc.image(LOGO, PAGE_MARGIN, PAGE_MARGIN - 8, { fit: [44, 44] });
      } catch {
        /* corrupt logo must not kill the report */
      }
    }
    doc
      .font(FONT_BOLD)
      .fontSize(16)
      .fillColor(GREEN)
      .text('BANAN FUKUOKA SAIGON', PAGE_MARGIN + 56, PAGE_MARGIN - 4);
    doc
      .font(FONT_BOLD)
      .fontSize(12)
      .fillColor(INK)
      .text(title, PAGE_MARGIN + 56, doc.y + 2);
    doc
      .font(FONT_REGULAR)
      .fontSize(9)
      .fillColor(MUTED)
      .text(`${store} · ${date}`, PAGE_MARGIN + 56, doc.y + 2);
    doc
      .moveTo(PAGE_MARGIN, PAGE_MARGIN + 52)
      .lineTo(doc.page.width - PAGE_MARGIN, PAGE_MARGIN + 52)
      .strokeColor(LINE)
      .stroke();
    doc.x = PAGE_MARGIN;
    doc.y = PAGE_MARGIN + 64;
  }

  private badge(doc: Doc, label: string, color: string): void {
    doc.font(FONT_BOLD).fontSize(14).fillColor(color).text(label);
  }

  private sectionTitle(doc: Doc, title: string): void {
    doc.font(FONT_BOLD).fontSize(11).fillColor(INK).text(title);
    doc
      .moveTo(PAGE_MARGIN, doc.y + 2)
      .lineTo(doc.page.width - PAGE_MARGIN, doc.y + 2)
      .strokeColor(LINE)
      .stroke();
    doc.moveDown(0.4);
  }

  private kv(doc: Doc, rows: [string, string][]): void {
    for (const [k, v] of rows) {
      const y = doc.y;
      doc.font(FONT_REGULAR).fontSize(9.5).fillColor(MUTED).text(k, PAGE_MARGIN, y, {
        width: 150,
        lineBreak: false,
      });
      doc
        .font(FONT_REGULAR)
        .fontSize(9.5)
        .fillColor(INK)
        .text(v, PAGE_MARGIN + 160, y, { width: this.contentWidth(doc) - 160 });
      doc.x = PAGE_MARGIN;
    }
  }

  /** Two-column row: label left, value right-aligned. */
  private row2(doc: Doc, left: string, right: string, rightColor: string): void {
    this.ensureRoom(doc, 16);
    const y = doc.y;
    const w = this.contentWidth(doc);
    doc
      .font(FONT_REGULAR)
      .fontSize(9.5)
      .fillColor(INK)
      .text(left, PAGE_MARGIN, y, { width: w - 120 });
    const endY = doc.y;
    doc
      .font(FONT_BOLD)
      .fontSize(9.5)
      .fillColor(rightColor)
      .text(right, PAGE_MARGIN + w - 116, y, { width: 116, align: 'right', lineBreak: false });
    doc.x = PAGE_MARGIN;
    doc.y = Math.max(endY, y + 13);
  }

  /**
   * Evidence thumbnails, aspect-preserving, wrapped in rows. Uploads are
   * served from local disk — map the URL back by basename and refuse
   * anything that escapes the uploads dir.
   */
  private images(doc: Doc, refs: PdfEvidenceRef[]): void {
    if (refs.length === 0) return;
    const size = 120;
    let x = PAGE_MARGIN + 12;
    this.ensureRoom(doc, size + 12);
    let rowTop = doc.y + 4;
    for (const ref of refs) {
      const file = this.resolveUpload(ref.url);
      if (x + size > doc.page.width - PAGE_MARGIN) {
        x = PAGE_MARGIN + 12;
        rowTop += size + 8;
        if (rowTop + size > doc.page.height - PAGE_MARGIN - 24) {
          doc.addPage();
          rowTop = doc.y;
        }
      }
      if (file) {
        try {
          doc.image(file, x, rowTop, { fit: [size, size] });
        } catch {
          doc
            .font(FONT_REGULAR)
            .fontSize(8)
            .fillColor(MUTED)
            .text('(ảnh lỗi)', x, rowTop + size / 2, { width: size, lineBreak: false });
        }
      } else {
        doc
          .font(FONT_REGULAR)
          .fontSize(8)
          .fillColor(MUTED)
          .text('(thiếu ảnh)', x, rowTop + size / 2, { width: size, lineBreak: false });
      }
      x += size + 8;
    }
    doc.x = PAGE_MARGIN;
    doc.y = rowTop + size + 8;
  }

  private resolveUpload(ref: string): Buffer | null {
    try {
      // Evidence refs are PRIVATE store names (hex + ext). Accept a stray
      // legacy URL too by taking its basename — still served from the
      // private dir only, never the public uploads mount.
      const name = basename(new URL(ref, 'http://localhost').pathname);
      if (!/^[a-f0-9]{32}\.(jpg|png|webp)$/.test(name)) return null;
      const path = join(process.cwd(), 'uploads-private', name);
      if (!existsSync(path)) return null;
      return readFileSync(path);
    } catch (err) {
      this.logger.warn(`Evidence unreadable for PDF: ${(err as Error).message}`);
      return null;
    }
  }
}

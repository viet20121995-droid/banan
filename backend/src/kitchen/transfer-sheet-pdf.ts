import { join } from 'node:path';

import PDFDocument from 'pdfkit';

import type { TransferSheetDay } from '../orders/transfer-sheet';

/**
 * "PHIẾU ĐẶT HÀNG & ĐÓNG GÓI" for one delivery day — the paper the packers
 * and the drivers carry: per branch what was asked and what goes, the total
 * and the shortfall, signature lines at the bottom. Landscape A4 so four
 * branches fit.
 */

const FONT_REGULAR = join(process.cwd(), 'assets', 'fonts', 'BeVietnamPro-Regular.ttf');
const FONT_BOLD = join(process.cwd(), 'assets', 'fonts', 'BeVietnamPro-Bold.ttf');

const INK = '#26221D';
const MUTED = '#6B5A52';
const LINE = '#D9CFC3';
const HEAD_BG = '#EFE6DA';
const SECTION_BG = '#F7F1E8';
const RED = '#C12B36';
const MARGIN = 28;
const ROW_H = 18;

const WEEKDAYS = ['Chủ nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'];

/** "Thứ 7 05/09/2026" from a `yyyy-MM-dd` VN day. */
export function transferDayLabel(day: string): string {
  const [y, m, d] = day.split('-').map(Number);
  const weekday = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  return `${WEEKDAYS[weekday]} ${String(d).padStart(2, '0')}/${String(m).padStart(2, '0')}/${y}`;
}

function fmt(v: number): string {
  return v === 0 ? '' : Number.isInteger(v) ? String(v) : v.toFixed(3).replace(/\.?0+$/, '');
}

export function renderTransferSheetPdf(
  day: TransferSheetDay,
  opts: { kitchenName?: string; printedAt?: Date } = {},
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({
      size: 'A4',
      layout: 'landscape',
      margins: { top: MARGIN, bottom: MARGIN, left: MARGIN, right: MARGIN },
      bufferPages: true,
      info: { Title: `Phiếu đặt hàng ${day.day}`, Author: 'Banan Fukuoka Saigon' },
    });
    const chunks: Buffer[] = [];
    doc.on('data', (c: Buffer) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
    doc.registerFont('viet', FONT_REGULAR);
    doc.registerFont('viet-bold', FONT_BOLD);

    const width = doc.page.width - MARGIN * 2;
    const stores = day.stores;
    // Columns: STT | Món | ĐVT | (Đặt Giao) × stores | Tổng đặt | Tổng giao | Thiếu
    const wStt = 26;
    const wUnit = 36;
    const wQty = 38;
    const wTot = 50;
    const wName = width - wStt - wUnit - wQty * 2 * stores.length - wTot * 3;
    const cols: number[] = [wStt, wName, wUnit];
    for (let i = 0; i < stores.length; i++) cols.push(wQty, wQty);
    cols.push(wTot, wTot, wTot);
    const xs: number[] = [];
    let acc = MARGIN;
    for (const c of cols) {
      xs.push(acc);
      acc += c;
    }

    const title = () => {
      doc
        .font('viet-bold')
        .fontSize(13)
        .fillColor(INK)
        .text('PHIẾU ĐẶT HÀNG & ĐÓNG GÓI — KHÁCH LẺ', MARGIN, MARGIN, {
          width,
          align: 'center',
        });
      doc
        .font('viet')
        .fontSize(9)
        .fillColor(MUTED)
        .text(
          `Giao ${transferDayLabel(day.day)}  ·  ${day.orders.length} phiếu: ${day.orders
            .map((o) => o.code)
            .join(', ')}${opts.kitchenName ? `  ·  ${opts.kitchenName}` : ''}`,
          MARGIN,
          doc.y + 2,
          { width, align: 'center' },
        );
      doc.moveDown(0.6);
    };

    const cell = (
      i: number,
      text: string,
      y: number,
      o: { bold?: boolean; align?: 'left' | 'right' | 'center'; color?: string } = {},
    ) => {
      doc
        .font(o.bold ? 'viet-bold' : 'viet')
        .fontSize(8)
        .fillColor(o.color ?? INK)
        .text(text, xs[i] + 3, y + 5, {
          width: cols[i] - 6,
          align: o.align ?? 'left',
          lineBreak: false,
        });
    };
    const hline = (y: number) =>
      doc
        .moveTo(MARGIN, y)
        .lineTo(MARGIN + width, y)
        .lineWidth(0.5)
        .strokeColor(LINE)
        .stroke();

    const header = () => {
      const y = doc.y;
      doc.rect(MARGIN, y, width, ROW_H * 2).fill(HEAD_BG);
      cell(0, 'STT', y + ROW_H / 2, { bold: true, align: 'center' });
      cell(1, 'Tên sản phẩm', y + ROW_H / 2, { bold: true });
      cell(2, 'ĐVT', y + ROW_H / 2, { bold: true, align: 'center' });
      stores.forEach((s, k) => {
        const i = 3 + k * 2;
        doc
          .font('viet-bold')
          .fontSize(8)
          .fillColor(INK)
          .text(s.name.replace(/^Banan\s*[–-]\s*/, ''), xs[i] + 2, y + 4, {
            width: wQty * 2 - 4,
            align: 'center',
            lineBreak: false,
          });
        cell(i, 'Đặt', y + ROW_H, { align: 'center', color: MUTED });
        cell(i + 1, 'Giao', y + ROW_H, { align: 'center', color: MUTED });
      });
      const t = 3 + stores.length * 2;
      cell(t, 'Tổng đặt', y + ROW_H / 2, { bold: true, align: 'center' });
      cell(t + 1, 'Tổng giao', y + ROW_H / 2, { bold: true, align: 'center' });
      cell(t + 2, 'Thiếu', y + ROW_H / 2, { bold: true, align: 'center', color: RED });
      doc.y = y + ROW_H * 2;
      hline(doc.y);
    };

    const ensureRoom = (h: number) => {
      if (doc.y + h > doc.page.height - MARGIN - 40) {
        doc.addPage();
        doc.y = MARGIN;
        header();
      }
    };

    title();
    header();

    const sections: Array<[string, (r: TransferSheetDay['rows'][number]) => boolean]> = [
      ['BÁNH / CAKE', (r) => !r.isSupply],
      ['NGUYÊN LIỆU PHA CHẾ', (r) => r.isSupply && r.isDrinkIngredient],
      ['BAO BÌ & VẬT TƯ', (r) => r.isSupply && !r.isDrinkIngredient],
    ];
    let stt = 0;
    let totalOrdered = 0;
    let totalShipped = 0;
    for (const [name, pick] of sections) {
      const rows = day.rows.filter(pick);
      if (rows.length === 0) continue;
      ensureRoom(ROW_H * 2);
      const sy = doc.y;
      doc.rect(MARGIN, sy, width, ROW_H).fill(SECTION_BG);
      cell(1, name, sy, { bold: true });
      doc.y = sy + ROW_H;
      for (const r of rows) {
        ensureRoom(ROW_H);
        const y = doc.y;
        stt++;
        cell(0, String(stt), y, { align: 'center', color: MUTED });
        cell(1, r.label, y);
        cell(2, r.unit, y, { align: 'center', color: MUTED });
        stores.forEach((s, k) => {
          const c = r.byStore[s.id];
          const i = 3 + k * 2;
          cell(i, c ? fmt(c.ordered) : '', y, { align: 'right' });
          cell(i + 1, c ? fmt(c.shipped) : '', y, {
            align: 'right',
            bold: true,
            color: c && c.shipped < c.ordered ? RED : INK,
          });
        });
        const t = 3 + stores.length * 2;
        const short = r.ordered - r.shipped;
        cell(t, fmt(r.ordered), y, { align: 'right' });
        cell(t + 1, fmt(r.shipped), y, { align: 'right', bold: true });
        cell(t + 2, short > 0 ? `-${fmt(short)}` : '', y, {
          align: 'right',
          bold: true,
          color: RED,
        });
        if (!r.isSupply) {
          totalOrdered += r.ordered;
          totalShipped += r.shipped;
        }
        doc.y = y + ROW_H;
        hline(doc.y);
      }
    }

    // Totals (cakes only — supplies mix units) + signatures.
    ensureRoom(ROW_H * 4 + 30);
    const y = doc.y;
    doc.rect(MARGIN, y, width, ROW_H).fill(HEAD_BG);
    cell(1, 'TỔNG BÁNH', y, { bold: true });
    const t = 3 + stores.length * 2;
    cell(t, fmt(totalOrdered), y, { align: 'right', bold: true });
    cell(t + 1, fmt(totalShipped), y, { align: 'right', bold: true });
    const short = totalOrdered - totalShipped;
    cell(t + 2, short > 0 ? `-${fmt(short)}` : '', y, { align: 'right', bold: true, color: RED });
    doc.y = y + ROW_H + 18;

    const sigW = width / 3;
    const sigY = doc.y;
    ['Bếp đóng gói', 'Giao hàng', 'Chi nhánh nhận'].forEach((label, i) => {
      doc
        .font('viet')
        .fontSize(9)
        .fillColor(INK)
        .text(label, MARGIN + sigW * i, sigY, { width: sigW, align: 'center', lineBreak: false });
      doc
        .font('viet')
        .fontSize(7)
        .fillColor(MUTED)
        .text('(ký, ghi rõ họ tên)', MARGIN + sigW * i, sigY + 12, {
          width: sigW,
          align: 'center',
          lineBreak: false,
        });
    });

    const printed = opts.printedAt ?? new Date();
    const range = doc.bufferedPageRange();
    for (let i = range.start; i < range.start + range.count; i++) {
      doc.switchToPage(i);
      doc.page.margins.bottom = 0;
      const fy = doc.page.height - MARGIN + 6;
      doc
        .font('viet')
        .fontSize(7)
        .fillColor(MUTED)
        .text(
          `In lúc ${printed.toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })}`,
          MARGIN,
          fy,
          {
            lineBreak: false,
          },
        )
        .text(`Trang ${i - range.start + 1}/${range.count}`, MARGIN, fy, {
          width,
          align: 'right',
          lineBreak: false,
        });
    }
    doc.end();
  });
}

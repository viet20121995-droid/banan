import { BadRequestException, Injectable } from '@nestjs/common';
import ExcelJS from 'exceljs';
import { Prisma, OrderStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

/// Date-range filter shared by every report endpoint. Both ends are
/// **inclusive** at the day level — `from` snaps to 00:00 ICT and `to`
/// snaps to 23:59:59 ICT so the merchant doesn't have to think in UTC.
export interface ReportRange {
  from: Date;
  to: Date;
  storeId: string | null; // null = chain-wide (admin)
}

/// Currencies are stored as Prisma Decimal — convert to plain JS number
/// at the API edge so Excel sheets get raw numeric values, not strings.
function num(d: Prisma.Decimal | null | undefined): number {
  if (!d) return 0;
  return Number(d.toString());
}

@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  /// Builds the canonical date range — used by every endpoint so the
  /// query semantics stay consistent ("from 2026-05-01 to 2026-05-31"
  /// means *every order placed on those days* inclusive).
  parseRange(input: { from?: string; to?: string; storeId?: string }): ReportRange {
    if (!input.from || !input.to) {
      throw new BadRequestException({
        code: 'RANGE_REQUIRED',
        message: 'Bạn cần chọn khoảng ngày (from, to).',
      });
    }
    const from = new Date(`${input.from}T00:00:00.000+07:00`);
    const to = new Date(`${input.to}T23:59:59.999+07:00`);
    if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime())) {
      throw new BadRequestException({
        code: 'RANGE_INVALID',
        message: 'Định dạng ngày không hợp lệ — dùng YYYY-MM-DD.',
      });
    }
    if (from > to) {
      throw new BadRequestException({
        code: 'RANGE_REVERSED',
        message: '`from` phải <= `to`.',
      });
    }
    // 1-year cap so a careless query can't sweep the entire table.
    if (to.getTime() - from.getTime() > 366 * 24 * 60 * 60 * 1000) {
      throw new BadRequestException({
        code: 'RANGE_TOO_LARGE',
        message: 'Khoảng ngày tối đa 1 năm.',
      });
    }
    return { from, to, storeId: input.storeId ?? null };
  }

  // ── Summary report ──────────────────────────────────────────────────

  async summary(r: ReportRange) {
    const where: Prisma.OrderWhereInput = {
      createdAt: { gte: r.from, lte: r.to },
      // Internal transfers move goods between branches — never retail revenue.
      source: { not: 'INTERNAL_TRANSFER' },
      ...(r.storeId && { storeId: r.storeId }),
    };
    const [orders, refunds] = await Promise.all([
      this.prisma.order.findMany({
        where,
        select: {
          status: true,
          subtotal: true,
          deliveryFee: true,
          total: true,
          couponDiscount: true,
          pointsDiscount: true,
          createdAt: true,
          fulfillmentType: true,
          payments: { select: { provider: true } },
        },
      }),
      this.prisma.refund.findMany({
        where: {
          order: where,
          status: 'COMPLETED',
        },
        select: { amount: true },
      }),
    ]);

    const totals = {
      orders: orders.length,
      completed: orders.filter((o) => o.status === OrderStatus.COMPLETED).length,
      cancelled: orders.filter((o) => o.status === OrderStatus.CANCELLED).length,
      revenue: 0,
      deliveryFees: 0,
      coupons: 0,
      pointsBurned: 0,
      avgOrderValue: 0,
      refundedAmount: refunds.reduce((s, r) => s + num(r.amount), 0),
    };
    for (const o of orders) {
      if (o.status === OrderStatus.COMPLETED) {
        totals.revenue += num(o.total);
      }
      totals.deliveryFees += num(o.deliveryFee);
      totals.coupons += num(o.couponDiscount);
      totals.pointsBurned += num(o.pointsDiscount);
    }
    totals.avgOrderValue = totals.completed > 0 ? Math.round(totals.revenue / totals.completed) : 0;

    // Daily revenue series (ICT day).
    const dailyMap = new Map<string, { revenue: number; orders: number }>();
    for (const o of orders) {
      const day = ictDay(o.createdAt);
      const row = dailyMap.get(day) ?? { revenue: 0, orders: 0 };
      row.orders += 1;
      if (o.status === OrderStatus.COMPLETED) {
        row.revenue += num(o.total);
      }
      dailyMap.set(day, row);
    }
    const daily = Array.from(dailyMap.entries())
      .map(([date, v]) => ({ date, ...v }))
      .sort((a, b) => a.date.localeCompare(b.date));

    // Fulfillment + payment method splits.
    const fulfillment = {
      pickup: orders.filter((o) => o.fulfillmentType === 'PICKUP').length,
      delivery: orders.filter((o) => o.fulfillmentType === 'DELIVERY').length,
    };
    const paymentMethods: Record<string, number> = {};
    for (const o of orders) {
      for (const p of o.payments) {
        paymentMethods[p.provider] = (paymentMethods[p.provider] ?? 0) + 1;
      }
    }

    return { range: r, totals, daily, fulfillment, paymentMethods };
  }

  // ── Product sales report (best sellers) ─────────────────────────────

  async productSales(r: ReportRange, limit = 50) {
    const items = await this.prisma.orderItem.findMany({
      where: {
        order: {
          createdAt: { gte: r.from, lte: r.to },
          status: { not: 'CANCELLED' },
          source: { not: 'INTERNAL_TRANSFER' },
          ...(r.storeId && { storeId: r.storeId }),
        },
      },
      select: {
        productId: true,
        productName: true,
        variantLabel: true,
        quantity: true,
        lineTotal: true,
      },
    });
    const agg = new Map<
      string,
      { productId: string; productName: string; unitsSold: number; revenue: number }
    >();
    for (const i of items) {
      const cur = agg.get(i.productId) ?? {
        productId: i.productId,
        productName: i.productName,
        unitsSold: 0,
        revenue: 0,
      };
      cur.unitsSold += i.quantity;
      cur.revenue += num(i.lineTotal);
      agg.set(i.productId, cur);
    }
    return Array.from(agg.values())
      .sort((a, b) => b.revenue - a.revenue)
      .slice(0, limit);
  }

  // ── Orders raw report ───────────────────────────────────────────────

  async orderRows(r: ReportRange, status?: OrderStatus) {
    return this.prisma.order.findMany({
      where: {
        createdAt: { gte: r.from, lte: r.to },
        source: { not: 'INTERNAL_TRANSFER' },
        ...(r.storeId && { storeId: r.storeId }),
        ...(status && { status }),
      },
      include: {
        customer: { select: { fullName: true, phone: true } },
        store: { select: { name: true } },
        items: { select: { productName: true, quantity: true } },
        payments: {
          select: { provider: true, status: true },
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ── Refunds report ──────────────────────────────────────────────────

  async refundRows(r: ReportRange) {
    return this.prisma.refund.findMany({
      where: {
        createdAt: { gte: r.from, lte: r.to },
        order: {
          source: { not: 'INTERNAL_TRANSFER' },
          ...(r.storeId && { storeId: r.storeId }),
        },
      },
      include: {
        order: {
          select: {
            code: true,
            store: { select: { name: true } },
            customer: { select: { fullName: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ── XLSX builders ───────────────────────────────────────────────────

  /// Multi-sheet workbook: 4 reports in 1 file. Each report endpoint
  /// returns the same buffer when `format=xlsx` — the merchant downloads
  /// one file and gets everything for the period.
  async buildWorkbook(r: ReportRange): Promise<Buffer> {
    const wb = new ExcelJS.Workbook();
    wb.creator = 'Banan';
    wb.created = new Date();

    // Sequential await preserves Prisma's include-aware return types —
    // Promise.all destructuring widens to the bare model on this version.
    const summary = await this.summary(r);
    const products = await this.productSales(r);
    const orders = await this.orderRows(r);
    const refunds = await this.refundRows(r);

    const fmtDate = (d: Date) => ictDay(d);
    const period = `${fmtDate(r.from)}  →  ${fmtDate(r.to)}`;

    // Sheet 1 — Summary KPIs
    const ws1 = wb.addWorksheet('Tổng quan', {
      properties: { defaultColWidth: 22 },
    });
    ws1.addRow(['Báo cáo Banan']).font = { bold: true, size: 16 };
    ws1.addRow(['Kỳ báo cáo', period]);
    ws1.addRow(['Chi nhánh', r.storeId ?? 'Toàn chuỗi']);
    ws1.addRow([]);
    ws1.addRow(['Chỉ số', 'Giá trị']).font = { bold: true };
    ws1.addRow(['Tổng đơn', summary.totals.orders]);
    ws1.addRow(['Đã hoàn tất', summary.totals.completed]);
    ws1.addRow(['Đã huỷ', summary.totals.cancelled]);
    ws1.addRow(['Doanh thu (₫)', summary.totals.revenue]);
    ws1.addRow(['Giá trị đơn trung bình (₫)', summary.totals.avgOrderValue]);
    ws1.addRow(['Phí giao hàng thu (₫)', summary.totals.deliveryFees]);
    ws1.addRow(['Khuyến mãi áp dụng (₫)', summary.totals.coupons]);
    ws1.addRow(['Điểm đã đổi (₫)', summary.totals.pointsBurned]);
    ws1.addRow(['Đã hoàn tiền (₫)', summary.totals.refundedAmount]);
    ws1.addRow([]);
    ws1.addRow(['Pickup', summary.fulfillment.pickup]);
    ws1.addRow(['Delivery', summary.fulfillment.delivery]);
    ws1.addRow([]);
    ws1.addRow(['Phương thức thanh toán']).font = { bold: true };
    for (const [m, count] of Object.entries(summary.paymentMethods)) {
      ws1.addRow([m, count]);
    }
    ws1.addRow([]);
    ws1.addRow(['Doanh thu theo ngày']).font = { bold: true };
    ws1.addRow(['Ngày', 'Đơn', 'Doanh thu (₫)']);
    for (const d of summary.daily) {
      ws1.addRow([d.date, d.orders, d.revenue]);
    }

    // Sheet 2 — Best-selling products
    const ws2 = wb.addWorksheet('Sản phẩm bán chạy');
    ws2.columns = [
      { header: 'STT', key: 'rank', width: 6 },
      { header: 'Tên sản phẩm', key: 'name', width: 40 },
      { header: 'Số lượng bán', key: 'units', width: 16 },
      { header: 'Doanh thu (₫)', key: 'revenue', width: 18 },
    ];
    ws2.getRow(1).font = { bold: true };
    products.forEach((p, i) => {
      ws2.addRow({
        rank: i + 1,
        name: p.productName,
        units: p.unitsSold,
        revenue: p.revenue,
      });
    });

    // Sheet 3 — Orders detail
    const ws3 = wb.addWorksheet('Chi tiết đơn hàng');
    ws3.columns = [
      { header: 'Mã đơn', key: 'code', width: 18 },
      { header: 'Ngày', key: 'date', width: 18 },
      { header: 'Khách', key: 'customer', width: 26 },
      { header: 'SĐT', key: 'phone', width: 14 },
      { header: 'Chi nhánh', key: 'store', width: 26 },
      { header: 'Hình thức', key: 'fulfillment', width: 12 },
      { header: 'Trạng thái', key: 'status', width: 16 },
      { header: 'Thanh toán', key: 'payment', width: 14 },
      { header: 'Số món', key: 'items', width: 8 },
      { header: 'Tạm tính (₫)', key: 'subtotal', width: 14 },
      { header: 'Phí giao (₫)', key: 'fee', width: 12 },
      { header: 'Tổng (₫)', key: 'total', width: 14 },
    ];
    ws3.getRow(1).font = { bold: true };
    for (const o of orders) {
      ws3.addRow({
        code: o.code,
        date: ictDateTime(o.createdAt),
        customer: o.customer.fullName,
        phone: o.customer.phone ?? '',
        store: o.store.name,
        fulfillment: o.fulfillmentType,
        status: o.status,
        payment: o.payments[0]?.provider ?? '',
        items: o.items.reduce((s, i) => s + i.quantity, 0),
        subtotal: num(o.subtotal),
        fee: num(o.deliveryFee),
        total: num(o.total),
      });
    }

    // Sheet 4 — Refunds
    const ws4 = wb.addWorksheet('Hoàn tiền');
    ws4.columns = [
      { header: 'Ngày', key: 'date', width: 18 },
      { header: 'Mã đơn', key: 'code', width: 18 },
      { header: 'Khách', key: 'customer', width: 26 },
      { header: 'Chi nhánh', key: 'store', width: 26 },
      { header: 'Số tiền (₫)', key: 'amount', width: 14 },
      { header: 'Trạng thái', key: 'status', width: 14 },
      { header: 'Lý do', key: 'reason', width: 40 },
    ];
    ws4.getRow(1).font = { bold: true };
    for (const f of refunds) {
      ws4.addRow({
        date: ictDateTime(f.createdAt),
        code: f.order.code,
        customer: f.order.customer.fullName,
        store: f.order.store.name,
        amount: num(f.amount),
        status: f.status,
        reason: f.reason ?? '',
      });
    }

    const buf = await wb.xlsx.writeBuffer();
    return Buffer.from(buf);
  }
}

// ── Helpers ────────────────────────────────────────────────────────────

/// ISO date in ICT (UTC+7). Used so daily series matches the merchant's
/// calendar day, not the UTC day where 7am ICT would belong to "yesterday".
function ictDay(d: Date): string {
  const ict = new Date(d.getTime() + 7 * 60 * 60 * 1000);
  return ict.toISOString().slice(0, 10);
}

function ictDateTime(d: Date): string {
  const ict = new Date(d.getTime() + 7 * 60 * 60 * 1000);
  return ict.toISOString().slice(0, 16).replace('T', ' ');
}

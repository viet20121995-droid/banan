import { BadRequestException, Injectable } from '@nestjs/common';
import ExcelJS from 'exceljs';
import { Prisma, OrderStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import {
  aggregateFlavors,
  aggregateProductSales,
  describePersonalization,
  ictDateTime,
  ictDay,
  ictHour,
  ictWeekday,
  num,
  type SalesItemInput,
} from './report-agg';

/// Date-range filter shared by every report endpoint. Both ends are
/// **inclusive** at the day level — `from` snaps to 00:00 ICT and `to`
/// snaps to 23:59:59 ICT so the merchant doesn't have to think in UTC.
export interface ReportRange {
  from: Date;
  to: Date;
  storeId: string | null; // null = chain-wide (admin)
}

const SOURCE_LABEL: Record<string, string> = {
  WEB: 'Website',
  STAFF_COUNTER: 'Tại quầy',
  WHOLESALE: 'Sỉ / hợp đồng',
};
const STATUS_LABEL: Record<string, string> = {
  PENDING: 'Chờ xác nhận',
  ACCEPTED: 'Đã nhận',
  IN_PREPARATION: 'Đang chuẩn bị',
  SENT_TO_KITCHEN: 'Đã gửi bếp',
  READY_FOR_PICKUP: 'Sẵn sàng',
  DELIVERING: 'Đang giao',
  COMPLETED: 'Hoàn tất',
  CANCELLED: 'Đã huỷ',
  REFUNDED: 'Đã hoàn tiền',
};
const PAYMENT_LABEL: Record<string, string> = {
  NINEPAY: '9Pay (online)',
  CASH: 'Tiền mặt',
  MOMO: 'MoMo',
  PAYOS: 'PayOS (cũ)',
  VNPAY: 'VNPay (cũ)',
  STRIPE: 'Stripe',
};
const WEEKDAY_LABEL = ['Chủ nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'];
const label = (map: Record<string, string>, k: string) => map[k] ?? k;

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

  private orderWhere(r: ReportRange): Prisma.OrderWhereInput {
    return {
      createdAt: { gte: r.from, lte: r.to },
      // Internal transfers move goods between branches — never retail revenue.
      source: { not: 'INTERNAL_TRANSFER' },
      ...(r.storeId && { storeId: r.storeId }),
    };
  }

  // ── Summary report ──────────────────────────────────────────────────

  async summary(r: ReportRange) {
    const where = this.orderWhere(r);
    const [orders, refunds] = await Promise.all([
      this.prisma.order.findMany({
        where,
        select: {
          status: true,
          source: true,
          subtotal: true,
          deliveryFee: true,
          total: true,
          couponDiscount: true,
          pointsDiscount: true,
          campaignDiscount: true,
          bundleDiscount: true,
          giftCardAmountVnd: true,
          createdAt: true,
          scheduledFor: true,
          isGift: true,
          fulfillmentType: true,
          customerId: true,
          customer: { select: { fullName: true, phone: true } },
          store: { select: { id: true, name: true } },
          payments: {
            select: { provider: true },
            orderBy: { createdAt: 'desc' },
            take: 1,
          },
          items: {
            select: {
              quantity: true,
              lineTotal: true,
              product: { select: { category: { select: { name: true } } } },
            },
          },
        },
      }),
      this.prisma.refund.findMany({
        where: { order: where, status: 'COMPLETED' },
        select: { amount: true },
      }),
    ]);

    const done = (o: { status: OrderStatus }) => o.status === OrderStatus.COMPLETED;
    const completedOrders = orders.filter(done);
    const cancelledOrders = orders.filter((o) => o.status === OrderStatus.CANCELLED);
    const sum = <T>(xs: T[], f: (x: T) => number) => xs.reduce((s, x) => s + f(x), 0);

    // New vs returning: a customer is "new" when their first-ever order
    // falls inside the period.
    const customerIds = [...new Set(orders.map((o) => o.customerId))];
    const firstOrders = customerIds.length
      ? await this.prisma.order.groupBy({
          by: ['customerId'],
          where: { customerId: { in: customerIds }, source: { not: 'INTERNAL_TRANSFER' } },
          _min: { createdAt: true },
        })
      : [];
    const newCustomers = firstOrders.filter(
      (f) => f._min.createdAt && f._min.createdAt >= r.from,
    ).length;

    const revenue = sum(completedOrders, (o) => num(o.total));
    const itemsSold = sum(completedOrders, (o) => sum(o.items, (i) => i.quantity));
    const totals = {
      orders: orders.length,
      completed: completedOrders.length,
      cancelled: cancelledOrders.length,
      inProgress: orders.length - completedOrders.length - cancelledOrders.length,
      revenue,
      grossSales: sum(completedOrders, (o) => num(o.subtotal)),
      discounts: sum(
        completedOrders,
        (o) =>
          num(o.couponDiscount) +
          num(o.pointsDiscount) +
          num(o.campaignDiscount) +
          num(o.bundleDiscount) +
          o.giftCardAmountVnd,
      ),
      deliveryFees: sum(completedOrders, (o) => num(o.deliveryFee)),
      coupons: sum(orders, (o) => num(o.couponDiscount)),
      campaignDiscounts: sum(orders, (o) => num(o.campaignDiscount)),
      bundleDiscounts: sum(orders, (o) => num(o.bundleDiscount)),
      giftCards: sum(orders, (o) => o.giftCardAmountVnd),
      pointsBurned: sum(orders, (o) => num(o.pointsDiscount)),
      avgOrderValue: completedOrders.length ? Math.round(revenue / completedOrders.length) : 0,
      itemsSold,
      avgItemsPerOrder: completedOrders.length
        ? Math.round((itemsSold / completedOrders.length) * 10) / 10
        : 0,
      cancelRate: orders.length
        ? Math.round((cancelledOrders.length / orders.length) * 1000) / 10
        : 0,
      cancelledValue: sum(cancelledOrders, (o) => num(o.total)),
      refundedAmount: sum(refunds, (x) => num(x.amount)),
      uniqueCustomers: customerIds.length,
      newCustomers,
      returningCustomers: customerIds.length - newCustomers,
      giftOrders: orders.filter((o) => o.isGift).length,
      scheduledOrders: orders.filter((o) => o.scheduledFor).length,
    };

    // Daily series (ICT day).
    type DayRow = {
      date: string;
      orders: number;
      completed: number;
      cancelled: number;
      items: number;
      revenue: number;
    };
    const dailyMap = new Map<string, DayRow>();
    for (const o of orders) {
      const day = ictDay(o.createdAt);
      const row = dailyMap.get(day) ?? {
        date: day,
        orders: 0,
        completed: 0,
        cancelled: 0,
        items: 0,
        revenue: 0,
      };
      row.orders += 1;
      if (done(o)) {
        row.completed += 1;
        row.revenue += num(o.total);
        row.items += sum(o.items, (i) => i.quantity);
      }
      if (o.status === OrderStatus.CANCELLED) row.cancelled += 1;
      dailyMap.set(day, row);
    }
    const daily = Array.from(dailyMap.values()).sort((a, b) => a.date.localeCompare(b.date));

    const fulfillment = {
      pickup: orders.filter((o) => o.fulfillmentType === 'PICKUP').length,
      delivery: orders.filter((o) => o.fulfillmentType === 'DELIVERY').length,
      pickupRevenue: sum(
        completedOrders.filter((o) => o.fulfillmentType === 'PICKUP'),
        (o) => num(o.total),
      ),
      deliveryRevenue: sum(
        completedOrders.filter((o) => o.fulfillmentType === 'DELIVERY'),
        (o) => num(o.total),
      ),
    };

    const paymentMethods: Record<string, number> = {};
    for (const o of orders) {
      const p = o.payments[0]?.provider ?? (o.source === 'WHOLESALE' ? 'ON_ACCOUNT' : 'NONE');
      paymentMethods[p] = (paymentMethods[p] ?? 0) + 1;
    }

    const byStatus: Record<string, number> = {};
    for (const o of orders) byStatus[o.status] = (byStatus[o.status] ?? 0) + 1;

    const group = <K extends string>(
      key: (o: (typeof orders)[number]) => K,
      name: (k: K, o: (typeof orders)[number]) => string,
    ) => {
      const m = new Map<
        K,
        {
          key: K;
          name: string;
          orders: number;
          completed: number;
          cancelled: number;
          revenue: number;
        }
      >();
      for (const o of orders) {
        const k = key(o);
        const row = m.get(k) ?? {
          key: k,
          name: name(k, o),
          orders: 0,
          completed: 0,
          cancelled: 0,
          revenue: 0,
        };
        row.orders += 1;
        if (done(o)) {
          row.completed += 1;
          row.revenue += num(o.total);
        }
        if (o.status === OrderStatus.CANCELLED) row.cancelled += 1;
        m.set(k, row);
      }
      return Array.from(m.values()).sort((a, b) => b.revenue - a.revenue || b.orders - a.orders);
    };
    const bySource = group(
      (o) => o.source as string,
      (k) => label(SOURCE_LABEL, k),
    );
    const byStore = group(
      (o) => o.store.id,
      (_, o) => o.store.name,
    );

    // Category split — completed orders only, so it reconciles with revenue.
    const catMap = new Map<string, { category: string; units: number; revenue: number }>();
    for (const o of completedOrders) {
      for (const i of o.items) {
        const c = i.product.category?.name ?? 'Khác';
        const row = catMap.get(c) ?? { category: c, units: 0, revenue: 0 };
        row.units += i.quantity;
        row.revenue += num(i.lineTotal);
        catMap.set(c, row);
      }
    }
    const byCategory = Array.from(catMap.values()).sort((a, b) => b.revenue - a.revenue);

    const byHour = Array.from({ length: 24 }, (_, hour) => ({ hour, orders: 0, revenue: 0 }));
    const byWeekday = WEEKDAY_LABEL.map((name, weekday) => ({
      weekday,
      name,
      orders: 0,
      revenue: 0,
    }));
    for (const o of orders) {
      const h = byHour[ictHour(o.createdAt)];
      const w = byWeekday[ictWeekday(o.createdAt)];
      h.orders += 1;
      w.orders += 1;
      if (done(o)) {
        h.revenue += num(o.total);
        w.revenue += num(o.total);
      }
    }

    const custMap = new Map<
      string,
      { name: string; phone: string; orders: number; completed: number; revenue: number }
    >();
    for (const o of orders) {
      const row = custMap.get(o.customerId) ?? {
        name: o.customer.fullName,
        phone: o.customer.phone ?? '',
        orders: 0,
        completed: 0,
        revenue: 0,
      };
      row.orders += 1;
      if (done(o)) {
        row.completed += 1;
        row.revenue += num(o.total);
      }
      custMap.set(o.customerId, row);
    }
    const topCustomers = Array.from(custMap.values())
      .sort((a, b) => b.revenue - a.revenue || b.orders - a.orders)
      .slice(0, 20);

    return {
      range: r,
      totals,
      daily,
      fulfillment,
      paymentMethods,
      byStatus,
      bySource,
      byStore,
      byCategory,
      byHour,
      byWeekday,
      topCustomers,
    };
  }

  // ── Product sales report (best sellers, per variant) ────────────────

  private async salesItems(r: ReportRange): Promise<SalesItemInput[]> {
    const items = await this.prisma.orderItem.findMany({
      where: { order: { ...this.orderWhere(r), status: { not: 'CANCELLED' } } },
      select: {
        orderId: true,
        productId: true,
        productName: true,
        variantLabel: true,
        quantity: true,
        lineTotal: true,
        personalization: true,
        variant: { select: { sku: true } },
        product: { select: { category: { select: { name: true } } } },
      },
    });
    return items.map((i) => ({
      orderId: i.orderId,
      productId: i.productId,
      productName: i.productName,
      variantLabel: i.variantLabel,
      sku: i.variant?.sku ?? null,
      category: i.product.category?.name ?? null,
      quantity: i.quantity,
      lineTotal: i.lineTotal,
      personalization: i.personalization,
    }));
  }

  async productSales(r: ReportRange, limit = 50) {
    return aggregateProductSales(await this.salesItems(r), limit);
  }

  async flavorSales(r: ReportRange) {
    return aggregateFlavors(await this.salesItems(r));
  }

  // ── Orders raw report ───────────────────────────────────────────────

  async orderRows(r: ReportRange, status?: OrderStatus) {
    return this.prisma.order.findMany({
      where: { ...this.orderWhere(r), ...(status && { status }) },
      include: {
        customer: { select: { fullName: true, phone: true, email: true } },
        store: { select: { name: true } },
        address: { select: { line1: true, line2: true, district: true, city: true } },
        coupon: { select: { code: true } },
        createdBy: { select: { fullName: true } },
        items: {
          select: {
            productName: true,
            variantLabel: true,
            quantity: true,
            unitPrice: true,
            lineTotal: true,
            customMessage: true,
            personalization: true,
            variant: { select: { sku: true } },
            product: { select: { category: { select: { name: true } } } },
          },
        },
        payments: {
          select: { provider: true, status: true, amount: true },
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
        statusEvents: {
          select: { toStatus: true, note: true, createdAt: true },
          orderBy: { createdAt: 'asc' },
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

  // ── XLSX builder ────────────────────────────────────────────────────

  /// Multi-sheet workbook: every report for the period in one file.
  async buildWorkbook(r: ReportRange): Promise<Buffer> {
    const wb = new ExcelJS.Workbook();
    wb.creator = 'Banan';
    wb.created = new Date();

    // Sequential await preserves Prisma's include-aware return types —
    // Promise.all destructuring widens to the bare model on this version.
    const summary = await this.summary(r);
    const products = await this.productSales(r, 500);
    const flavors = await this.flavorSales(r);
    const orders = await this.orderRows(r);
    const refunds = await this.refundRows(r);
    const storeName = r.storeId
      ? ((await this.prisma.store.findUnique({ where: { id: r.storeId } }))?.name ?? r.storeId)
      : 'Toàn chuỗi';

    const period = `${ictDay(r.from)} → ${ictDay(r.to)}`;
    const VND = '#,##0';
    const PCT = '0.0"%"';
    const HEADER_FILL: ExcelJS.Fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'FFF3E2D0' },
    };

    /// Tabular sheet: bold header row, filter, frozen header, number formats.
    const table = (
      name: string,
      columns: { header: string; key: string; width?: number; fmt?: string }[],
      rows: Record<string, unknown>[],
    ) => {
      const ws = wb.addWorksheet(name, { views: [{ state: 'frozen', ySplit: 1 }] });
      ws.columns = columns.map((c) => ({
        header: c.header,
        key: c.key,
        width: c.width ?? 16,
        style: c.fmt ? { numFmt: c.fmt } : undefined,
      }));
      ws.getRow(1).font = { bold: true };
      ws.getRow(1).fill = HEADER_FILL;
      ws.autoFilter = { from: { row: 1, column: 1 }, to: { row: 1, column: columns.length } };
      for (const row of rows) ws.addRow(row);
      return ws;
    };

    // Sheet 1 — Overview: KPI block + every split.
    const ws1 = wb.addWorksheet('Tổng quan');
    ws1.getColumn(1).width = 34;
    ws1.getColumn(2).width = 18;
    ws1.getColumn(3).width = 14;
    ws1.getColumn(4).width = 14;
    ws1.getColumn(5).width = 18;
    const title = ws1.addRow(['Báo cáo kinh doanh Banan']);
    title.font = { bold: true, size: 16 };
    ws1.addRow(['Kỳ báo cáo', period]);
    ws1.addRow(['Chi nhánh', storeName]);
    ws1.addRow(['Xuất lúc', ictDateTime(new Date())]);
    ws1.addRow([]);
    const section = (name: string, headers: string[]) => {
      ws1.addRow([]);
      ws1.addRow([name]).font = { bold: true, size: 12 };
      const h = ws1.addRow(headers);
      h.font = { bold: true };
      h.fill = HEADER_FILL;
    };
    const kpi = (name: string, value: number | string, fmt?: string) => {
      const row = ws1.addRow([name, value]);
      if (fmt) row.getCell(2).numFmt = fmt;
    };
    const t = summary.totals;
    section('Chỉ số chính', ['Chỉ số', 'Giá trị']);
    kpi('Doanh thu thực thu (đơn hoàn tất, ₫)', t.revenue, VND);
    kpi('Giá trị hàng bán trước giảm (₫)', t.grossSales, VND);
    kpi('Tổng giảm giá trên đơn hoàn tất (₫)', t.discounts, VND);
    kpi('Phí giao hàng thu (₫)', t.deliveryFees, VND);
    kpi('Đã hoàn tiền (₫)', t.refundedAmount, VND);
    kpi('Giá trị đơn trung bình (₫)', t.avgOrderValue, VND);
    kpi('Tổng đơn (mọi trạng thái)', t.orders);
    kpi('Đơn hoàn tất', t.completed);
    kpi('Đơn đang xử lý', t.inProgress);
    kpi('Đơn huỷ', t.cancelled);
    kpi('Tỉ lệ huỷ', t.cancelRate, PCT);
    kpi('Giá trị đơn huỷ (₫)', t.cancelledValue, VND);
    kpi('Số sản phẩm bán ra (đơn hoàn tất)', t.itemsSold);
    kpi('Số sản phẩm trung bình / đơn', t.avgItemsPerOrder);
    kpi('Khách hàng mua trong kỳ', t.uniqueCustomers);
    kpi('  · Khách mới (đơn đầu tiên trong kỳ)', t.newCustomers);
    kpi('  · Khách quay lại', t.returningCustomers);
    kpi('Đơn tặng quà', t.giftOrders);
    kpi('Đơn đặt trước (hẹn giờ)', t.scheduledOrders);
    section('Giảm giá theo loại (mọi đơn, ₫)', ['Loại', 'Số tiền']);
    kpi('Mã khuyến mãi', t.coupons, VND);
    kpi('Chương trình tự động (campaign)', t.campaignDiscounts, VND);
    kpi('Giảm combo', t.bundleDiscounts, VND);
    kpi('Thẻ quà tặng', t.giftCards, VND);
    kpi('Điểm thưởng đã đổi', t.pointsBurned, VND);
    section('Theo trạng thái', ['Trạng thái', 'Số đơn']);
    for (const [s, n] of Object.entries(summary.byStatus)) kpi(label(STATUS_LABEL, s), n);
    section('Theo kênh bán', ['Kênh', 'Số đơn', 'Hoàn tất', 'Huỷ', 'Doanh thu (₫)']);
    for (const s of summary.bySource) {
      const row = ws1.addRow([s.name, s.orders, s.completed, s.cancelled, s.revenue]);
      row.getCell(5).numFmt = VND;
    }
    section('Theo hình thức nhận hàng', ['Hình thức', 'Số đơn', '', '', 'Doanh thu (₫)']);
    ws1
      .addRow([
        'Lấy tại quầy',
        summary.fulfillment.pickup,
        '',
        '',
        summary.fulfillment.pickupRevenue,
      ])
      .getCell(5).numFmt = VND;
    ws1
      .addRow([
        'Giao hàng',
        summary.fulfillment.delivery,
        '',
        '',
        summary.fulfillment.deliveryRevenue,
      ])
      .getCell(5).numFmt = VND;
    section('Theo phương thức thanh toán', ['Phương thức', 'Số đơn']);
    for (const [m, n] of Object.entries(summary.paymentMethods)) kpi(label(PAYMENT_LABEL, m), n);
    section('Theo chi nhánh', ['Chi nhánh', 'Số đơn', 'Hoàn tất', 'Huỷ', 'Doanh thu (₫)']);
    for (const s of summary.byStore) {
      const row = ws1.addRow([s.name, s.orders, s.completed, s.cancelled, s.revenue]);
      row.getCell(5).numFmt = VND;
    }
    section('Theo danh mục (đơn hoàn tất)', ['Danh mục', 'Số lượng', '', '', 'Doanh thu (₫)']);
    for (const c of summary.byCategory) {
      ws1.addRow([c.category, c.units, '', '', c.revenue]).getCell(5).numFmt = VND;
    }
    section('Theo thứ trong tuần', ['Thứ', 'Số đơn', '', '', 'Doanh thu (₫)']);
    for (const w of summary.byWeekday) {
      ws1.addRow([w.name, w.orders, '', '', w.revenue]).getCell(5).numFmt = VND;
    }
    section('Theo giờ đặt (giờ VN)', ['Giờ', 'Số đơn', '', '', 'Doanh thu (₫)']);
    for (const h of summary.byHour) {
      if (h.orders === 0) continue;
      ws1
        .addRow([`${String(h.hour).padStart(2, '0')}:00`, h.orders, '', '', h.revenue])
        .getCell(5).numFmt = VND;
    }

    // Sheet 2 — Daily
    table(
      'Theo ngày',
      [
        { header: 'Ngày', key: 'date', width: 14 },
        { header: 'Số đơn', key: 'orders', width: 10 },
        { header: 'Hoàn tất', key: 'completed', width: 10 },
        { header: 'Huỷ', key: 'cancelled', width: 8 },
        { header: 'Sản phẩm bán', key: 'items', width: 14 },
        { header: 'Doanh thu (₫)', key: 'revenue', width: 18, fmt: VND },
        { header: 'TB / đơn (₫)', key: 'avg', width: 16, fmt: VND },
      ],
      summary.daily.map((d) => ({
        ...d,
        avg: d.completed ? Math.round(d.revenue / d.completed) : 0,
      })),
    );

    // Sheet 3 — Best sellers per variant
    table(
      'Sản phẩm bán chạy',
      [
        { header: 'STT', key: 'rank', width: 6 },
        { header: 'Sản phẩm', key: 'name', width: 34 },
        { header: 'Biến thể (size · vị)', key: 'variant', width: 28 },
        { header: 'SKU', key: 'sku', width: 12 },
        { header: 'Danh mục', key: 'category', width: 22 },
        { header: 'Số đơn', key: 'orders', width: 10 },
        { header: 'Số lượng', key: 'units', width: 10 },
        { header: 'Doanh thu (₫)', key: 'revenue', width: 18, fmt: VND },
        { header: 'Tỉ trọng', key: 'share', width: 10, fmt: PCT },
      ],
      products.map((p, i) => ({
        rank: i + 1,
        name: p.productName,
        variant: p.variantLabel,
        sku: p.sku,
        category: p.category,
        orders: p.orders,
        units: p.unitsSold,
        revenue: p.revenue,
        share: p.share,
      })),
    );

    // Sheet 4 — Flavour picks inside sets
    table(
      'Hương vị trong set',
      [
        { header: 'Sản phẩm', key: 'productName', width: 34 },
        { header: 'Hương vị', key: 'flavor', width: 28 },
        { header: 'Số cái', key: 'units', width: 10 },
      ],
      flavors.map((f) => ({ ...f })),
    );

    // Sheet 5 — Customers
    table(
      'Khách hàng',
      [
        { header: 'STT', key: 'rank', width: 6 },
        { header: 'Khách hàng', key: 'name', width: 30 },
        { header: 'SĐT', key: 'phone', width: 16 },
        { header: 'Số đơn', key: 'orders', width: 10 },
        { header: 'Hoàn tất', key: 'completed', width: 10 },
        { header: 'Doanh thu (₫)', key: 'revenue', width: 18, fmt: VND },
      ],
      summary.topCustomers.map((c, i) => ({ rank: i + 1, ...c })),
    );

    // Sheet 6 — Orders detail
    const eventAt = (o: (typeof orders)[number], status: string) =>
      o.statusEvents.filter((e) => e.toStatus === status).at(-1);
    table(
      'Đơn hàng',
      [
        { header: 'Mã đơn', key: 'code', width: 18 },
        { header: 'Ngày đặt', key: 'date', width: 17 },
        { header: 'Hẹn giao/nhận', key: 'scheduled', width: 17 },
        { header: 'Hoàn tất lúc', key: 'completedAt', width: 17 },
        { header: 'Khách', key: 'customer', width: 26 },
        { header: 'SĐT', key: 'phone', width: 14 },
        { header: 'Email', key: 'email', width: 26 },
        { header: 'Chi nhánh', key: 'store', width: 24 },
        { header: 'Kênh', key: 'source', width: 14 },
        { header: 'Người tạo', key: 'createdBy', width: 18 },
        { header: 'Hình thức', key: 'fulfillment', width: 12 },
        { header: 'Địa chỉ giao', key: 'address', width: 40 },
        { header: 'Trạng thái', key: 'status', width: 16 },
        { header: 'Lý do huỷ', key: 'cancelReason', width: 28 },
        { header: 'Thanh toán', key: 'payment', width: 16 },
        { header: 'TT thanh toán', key: 'paymentStatus', width: 14 },
        { header: 'Số món', key: 'items', width: 8 },
        { header: 'Chi tiết món', key: 'itemsText', width: 60 },
        { header: 'Tạm tính (₫)', key: 'subtotal', width: 14, fmt: VND },
        { header: 'Mã KM', key: 'coupon', width: 12 },
        { header: 'Giảm KM (₫)', key: 'couponDiscount', width: 12, fmt: VND },
        { header: 'Giảm campaign (₫)', key: 'campaignDiscount', width: 14, fmt: VND },
        { header: 'Giảm combo (₫)', key: 'bundleDiscount', width: 12, fmt: VND },
        { header: 'Điểm đổi (₫)', key: 'pointsDiscount', width: 12, fmt: VND },
        { header: 'Thẻ quà (₫)', key: 'giftCard', width: 12, fmt: VND },
        { header: 'Phí giao (₫)', key: 'fee', width: 12, fmt: VND },
        { header: 'Tổng (₫)', key: 'total', width: 14, fmt: VND },
        { header: 'Quà tặng', key: 'gift', width: 10 },
        { header: 'Người nhận quà', key: 'giftRecipient', width: 22 },
        { header: 'Lời nhắn', key: 'giftMessage', width: 30 },
        { header: 'Ghi chú', key: 'notes', width: 30 },
        { header: 'Hoá đơn VAT', key: 'vat', width: 26 },
      ],
      orders.map((o) => ({
        code: o.code,
        date: ictDateTime(o.createdAt),
        scheduled: ictDateTime(o.scheduledFor),
        completedAt: ictDateTime(eventAt(o, 'COMPLETED')?.createdAt),
        customer: o.customer.fullName,
        phone: o.customer.phone ?? '',
        email: o.customer.email,
        store: o.store.name,
        source: label(SOURCE_LABEL, o.source),
        createdBy: o.createdBy?.fullName ?? '',
        fulfillment: o.fulfillmentType === 'PICKUP' ? 'Lấy tại quầy' : 'Giao hàng',
        address: o.address
          ? [o.address.line1, o.address.line2, o.address.district, o.address.city]
              .filter(Boolean)
              .join(', ')
          : '',
        status: label(STATUS_LABEL, o.status),
        cancelReason: o.status === 'CANCELLED' ? (eventAt(o, 'CANCELLED')?.note ?? '') : '',
        payment: o.payments[0] ? label(PAYMENT_LABEL, o.payments[0].provider) : '',
        paymentStatus: o.payments[0]?.status ?? '',
        items: o.items.reduce((s, i) => s + i.quantity, 0),
        itemsText: o.items
          .map((i) => {
            const v = i.variantLabel && i.variantLabel !== 'Default' ? ` (${i.variantLabel})` : '';
            const p = describePersonalization(i.personalization);
            return `${i.quantity}× ${i.productName}${v}${p ? ` [${p}]` : ''}`;
          })
          .join('; '),
        subtotal: num(o.subtotal),
        coupon: o.coupon?.code ?? '',
        couponDiscount: num(o.couponDiscount),
        campaignDiscount: num(o.campaignDiscount),
        bundleDiscount: num(o.bundleDiscount),
        pointsDiscount: num(o.pointsDiscount),
        giftCard: o.giftCardAmountVnd,
        fee: num(o.deliveryFee),
        total: num(o.total),
        gift: o.isGift ? 'Có' : '',
        giftRecipient: o.isGift
          ? [o.giftRecipientName, o.giftRecipientPhone].filter(Boolean).join(' · ')
          : '',
        giftMessage: o.giftMessage ?? '',
        notes: [o.notes, o.customMessage].filter(Boolean).join(' · '),
        vat: o.requestVatInvoice
          ? [o.invoiceCompanyName, o.invoiceTaxId].filter(Boolean).join(' · ')
          : '',
      })),
    );

    // Sheet 7 — Line items (one row per product line)
    table(
      'Dòng hàng',
      [
        { header: 'Mã đơn', key: 'code', width: 18 },
        { header: 'Ngày đặt', key: 'date', width: 17 },
        { header: 'Chi nhánh', key: 'store', width: 24 },
        { header: 'Trạng thái đơn', key: 'status', width: 16 },
        { header: 'Sản phẩm', key: 'product', width: 34 },
        { header: 'Biến thể (size · vị)', key: 'variant', width: 28 },
        { header: 'SKU', key: 'sku', width: 12 },
        { header: 'Danh mục', key: 'category', width: 22 },
        { header: 'Tuỳ chọn / hương vị', key: 'personalization', width: 40 },
        { header: 'Lời nhắn trên bánh', key: 'message', width: 26 },
        { header: 'Số lượng', key: 'qty', width: 10 },
        { header: 'Đơn giá (₫)', key: 'unitPrice', width: 14, fmt: VND },
        { header: 'Thành tiền (₫)', key: 'lineTotal', width: 16, fmt: VND },
      ],
      orders.flatMap((o) =>
        o.items.map((i) => ({
          code: o.code,
          date: ictDateTime(o.createdAt),
          store: o.store.name,
          status: label(STATUS_LABEL, o.status),
          product: i.productName,
          variant: i.variantLabel ?? '',
          sku: i.variant?.sku ?? '',
          category: i.product.category?.name ?? '',
          personalization: describePersonalization(i.personalization),
          message: i.customMessage ?? '',
          qty: i.quantity,
          unitPrice: num(i.unitPrice),
          lineTotal: num(i.lineTotal),
        })),
      ),
    );

    // Sheet 8 — Refunds
    table(
      'Hoàn tiền',
      [
        { header: 'Ngày', key: 'date', width: 17 },
        { header: 'Mã đơn', key: 'code', width: 18 },
        { header: 'Khách', key: 'customer', width: 26 },
        { header: 'Chi nhánh', key: 'store', width: 24 },
        { header: 'Số tiền (₫)', key: 'amount', width: 14, fmt: VND },
        { header: 'Trạng thái', key: 'status', width: 14 },
        { header: 'Lý do', key: 'reason', width: 40 },
      ],
      refunds.map((f) => ({
        date: ictDateTime(f.createdAt),
        code: f.order.code,
        customer: f.order.customer.fullName,
        store: f.order.store.name,
        amount: num(f.amount),
        status: f.status,
        reason: f.reason ?? '',
      })),
    );

    const buf = await wb.xlsx.writeBuffer();
    return Buffer.from(buf);
  }
}

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

type RangeKey = '24h' | '7d' | '30d';

const RANGES: Record<RangeKey, number> = {
  '24h': 1,
  '7d': 7,
  '30d': 30,
};

interface DailyRevenuePoint {
  date: string; // YYYY-MM-DD
  revenue: number;
  orders: number;
}

interface BestSeller {
  productId: string;
  productName: string;
  unitsSold: number;
  revenue: number;
}

export interface MerchantSummary {
  range: RangeKey;
  totals: {
    revenue: number;
    orders: number;
    completed: number;
    cancelled: number;
    refunded: number;
    refundRate: number; // 0..1
    avgOrderValue: number;
  };
  daily: DailyRevenuePoint[];
  bestSellers: BestSeller[];
  /** Hour-of-day → order count, 0..23 covering the range. */
  peakHours: { hour: number; orders: number }[];
  /** Completed revenue + orders per branch (chain view; one entry when scoped). */
  byStore: { storeId: string; storeName: string; revenue: number; orders: number }[];
  /** Completed revenue + orders split by fulfillment type. */
  byFulfillment: {
    pickup: { revenue: number; orders: number };
    delivery: { revenue: number; orders: number };
  };
  /** Completed-order counts by payment provider. */
  byPayment: { provider: string; orders: number }[];
  /** Total discounts given on completed orders (coupon+campaign+points+gift card), VND. */
  discountsGiven: number;
}

export interface KitchenSummary {
  range: RangeKey;
  totals: {
    received: number;
    inProgress: number;
    dispatched: number;
    avgDispatchMinutes: number;
    capacityUtilization: number; // 0..1
  };
  daily: { date: string; orders: number }[];
}

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  parseRange(value: unknown): RangeKey {
    if (value === '24h' || value === '7d' || value === '30d') return value;
    return '7d';
  }

  async merchantSummary(storeId: string | null, range: RangeKey): Promise<MerchantSummary> {
    const { start, end } = this.window(range);
    // Admin (no storeId) sees aggregated stats across every store.
    const scope = storeId != null ? { storeId } : {};

    const [orders, items] = await this.prisma.$transaction([
      this.prisma.order.findMany({
        where: { ...scope, createdAt: { gte: start, lt: end } },
        select: {
          id: true,
          status: true,
          total: true,
          createdAt: true,
          storeId: true,
          store: { select: { name: true } },
          fulfillmentType: true,
          couponDiscount: true,
          campaignDiscount: true,
          bundleDiscount: true,
          pointsDiscount: true,
          giftCardAmountVnd: true,
          payments: { select: { provider: true } },
        },
      }),
      this.prisma.orderItem.findMany({
        where: {
          order: { ...scope, createdAt: { gte: start, lt: end } },
        },
        select: {
          productId: true,
          productName: true,
          quantity: true,
          lineTotal: true,
        },
      }),
    ]);

    let revenue = 0;
    let completed = 0;
    let cancelled = 0;
    let refunded = 0;
    const daily = new Map<string, DailyRevenuePoint>();
    const peak = Array.from({ length: 24 }, (_, h) => ({ hour: h, orders: 0 }));
    const byStoreMap = new Map<
      string,
      { storeId: string; storeName: string; revenue: number; orders: number }
    >();
    const ful = {
      pickup: { revenue: 0, orders: 0 },
      delivery: { revenue: 0, orders: 0 },
    };
    const payMap = new Map<string, number>();
    let discountsGiven = 0;

    for (const o of orders) {
      const total = Number(o.total.toString());
      const dayKey = o.createdAt.toISOString().slice(0, 10);
      if (!daily.has(dayKey)) {
        daily.set(dayKey, { date: dayKey, revenue: 0, orders: 0 });
      }
      const day = daily.get(dayKey)!;
      day.orders += 1;
      peak[o.createdAt.getHours()].orders += 1;
      if (o.status === 'COMPLETED') {
        completed += 1;
        revenue += total;
        day.revenue += total;
        const sb = byStoreMap.get(o.storeId) ?? {
          storeId: o.storeId,
          storeName: o.store?.name ?? '—',
          revenue: 0,
          orders: 0,
        };
        sb.revenue += total;
        sb.orders += 1;
        byStoreMap.set(o.storeId, sb);
        const fb = o.fulfillmentType === 'DELIVERY' ? ful.delivery : ful.pickup;
        fb.revenue += total;
        fb.orders += 1;
        const prov = o.payments[0]?.provider ?? 'UNKNOWN';
        payMap.set(prov, (payMap.get(prov) ?? 0) + 1);
        discountsGiven +=
          Number(o.couponDiscount.toString()) +
          Number(o.campaignDiscount.toString()) +
          Number(o.bundleDiscount.toString()) +
          Number(o.pointsDiscount.toString()) +
          o.giftCardAmountVnd;
      } else if (o.status === 'CANCELLED') {
        cancelled += 1;
      } else if (o.status === 'REFUNDED') {
        refunded += 1;
      }
    }

    const sellers = new Map<string, BestSeller>();
    for (const item of items) {
      const existing = sellers.get(item.productId) ?? {
        productId: item.productId,
        productName: item.productName,
        unitsSold: 0,
        revenue: 0,
      };
      existing.unitsSold += item.quantity;
      existing.revenue += Number(item.lineTotal.toString());
      sellers.set(item.productId, existing);
    }
    const bestSellers = [...sellers.values()].sort((a, b) => b.unitsSold - a.unitsSold).slice(0, 5);

    return {
      range,
      totals: {
        revenue,
        orders: orders.length,
        completed,
        cancelled,
        refunded,
        refundRate: orders.length === 0 ? 0 : (refunded + cancelled) / orders.length,
        avgOrderValue: completed === 0 ? 0 : revenue / completed,
      },
      daily: this.fillDaily(start, end, daily),
      bestSellers,
      peakHours: peak,
      byStore: [...byStoreMap.values()].sort((a, b) => b.revenue - a.revenue),
      byFulfillment: ful,
      byPayment: [...payMap.entries()]
        .map(([provider, orders]) => ({ provider, orders }))
        .sort((a, b) => b.orders - a.orders),
      discountsGiven,
    };
  }

  async kitchenSummary(kitchenId: string, range: RangeKey): Promise<KitchenSummary> {
    const { start, end } = this.window(range);

    const [orders, kitchen] = await this.prisma.$transaction([
      this.prisma.order.findMany({
        where: {
          kitchenId,
          OR: [
            { status: 'SENT_TO_KITCHEN' },
            {
              kitchenStatus: { not: null },
              createdAt: { gte: start, lt: end },
            },
          ],
        },
        select: {
          id: true,
          status: true,
          kitchenStatus: true,
          createdAt: true,
          updatedAt: true,
        },
      }),
      this.prisma.kitchen.findUnique({
        where: { id: kitchenId },
        select: { capacityPerHour: true },
      }),
    ]);

    let inProgress = 0;
    let dispatched = 0;
    let dispatchMinutesSum = 0;
    let dispatchedCounted = 0;
    const daily = new Map<string, { date: string; orders: number }>();

    for (const o of orders) {
      const dayKey = o.createdAt.toISOString().slice(0, 10);
      if (!daily.has(dayKey)) {
        daily.set(dayKey, { date: dayKey, orders: 0 });
      }
      daily.get(dayKey)!.orders += 1;

      if (o.status === 'SENT_TO_KITCHEN') {
        inProgress += 1;
      } else if (
        o.kitchenStatus === 'READY_DISPATCH' ||
        o.status === 'COMPLETED' ||
        o.status === 'READY_FOR_PICKUP' ||
        o.status === 'DELIVERING'
      ) {
        dispatched += 1;
        const elapsed = (o.updatedAt.getTime() - o.createdAt.getTime()) / 1000 / 60;
        dispatchMinutesSum += elapsed;
        dispatchedCounted += 1;
      }
    }

    const days = RANGES[range];
    const capacity = (kitchen?.capacityPerHour ?? 40) * 24 * days;
    const capacityUtilization = capacity === 0 ? 0 : orders.length / capacity;

    return {
      range,
      totals: {
        received: orders.length,
        inProgress,
        dispatched,
        avgDispatchMinutes: dispatchedCounted === 0 ? 0 : dispatchMinutesSum / dispatchedCounted,
        capacityUtilization,
      },
      daily: this.fillKitchenDaily(start, end, daily),
    };
  }

  private window(range: RangeKey): { start: Date; end: Date } {
    const end = new Date();
    end.setHours(23, 59, 59, 999);
    const start = new Date(end);
    start.setDate(end.getDate() - RANGES[range] + 1);
    start.setHours(0, 0, 0, 0);
    return { start, end };
  }

  /** Inserts zero-revenue rows for any days in [start, end) that are missing. */
  private fillDaily(
    start: Date,
    end: Date,
    map: Map<string, DailyRevenuePoint>,
  ): DailyRevenuePoint[] {
    const out: DailyRevenuePoint[] = [];
    const cursor = new Date(start);
    while (cursor < end) {
      const key = cursor.toISOString().slice(0, 10);
      out.push(map.get(key) ?? { date: key, revenue: 0, orders: 0 });
      cursor.setDate(cursor.getDate() + 1);
    }
    return out;
  }

  private fillKitchenDaily(
    start: Date,
    end: Date,
    map: Map<string, { date: string; orders: number }>,
  ): { date: string; orders: number }[] {
    const out: { date: string; orders: number }[] = [];
    const cursor = new Date(start);
    while (cursor < end) {
      const key = cursor.toISOString().slice(0, 10);
      out.push(map.get(key) ?? { date: key, orders: 0 });
      cursor.setDate(cursor.getDate() + 1);
    }
    return out;
  }

  // Tiny re-export so we can satisfy unused-import for Prisma if needed elsewhere.
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  private _typeAnchor = Prisma.JsonNull;
}

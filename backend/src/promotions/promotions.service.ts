import { BadRequestException, Injectable } from '@nestjs/common';
import { Campaign, CampaignType, MembershipTier, Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import { CreateCampaignDto, UpdateCampaignDto } from './dto';

/** All campaign types the checkout engine auto-applies (no code needed). */
const AUTO_TYPES: CampaignType[] = [
  'PRODUCT_DISCOUNT',
  'CATEGORY_DISCOUNT',
  'FLASH_SALE',
  'HAPPY_HOUR',
  'BUY_X_GET_Y',
  'FIRST_ORDER',
  'BIRTHDAY',
  'REACTIVATION',
  'MEMBERSHIP_BENEFIT',
];

/** Per-line discount types (each line takes the single best match). */
const LINE_TYPES: CampaignType[] = [
  'PRODUCT_DISCOUNT',
  'CATEGORY_DISCOUNT',
  'FLASH_SALE',
  'HAPPY_HOUR',
];

/** Order-level (customer-targeted) types — best single one applies. */
const ORDER_TYPES: CampaignType[] = [
  'FIRST_ORDER',
  'BIRTHDAY',
  'REACTIVATION',
  'MEMBERSHIP_BENEFIT',
];

export interface CartLine {
  productId: string;
  quantity: number;
  lineTotalVnd: number;
}

export interface AppliedCampaign {
  id: string;
  name: string;
  type: CampaignType;
  discountVnd: number;
}

export interface PromoResult {
  discountVnd: number;
  applied: AppliedCampaign[];
}

interface CustomerContext {
  orderCount: number;
  lastOrderAt: Date | null;
  birthday: Date | null;
  tier: MembershipTier | null;
}

@Injectable()
export class PromotionsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Evaluate active campaigns against a cart + customer. Pure read — the
   * caller subtracts the returned discount (and caps it at the subtotal).
   *
   * Stacking model:
   *  - line types (product/category/flash/happy-hour): each line gets its
   *    single best matching campaign (no double-discount on one product);
   *  - BUY_X_GET_Y: cart-level, cheapest qualifying units discounted;
   *  - order types (first-order/birthday/re-activation): the single best
   *    customer-targeted campaign, off the gross subtotal.
   * These three buckets sum; the caller caps the total at the subtotal.
   */
  async evaluate(input: {
    lines: CartLine[];
    storeId: string;
    subtotalVnd: number;
    customerId?: string;
    now?: Date;
  }): Promise<PromoResult> {
    const now = input.now ?? new Date();
    if (input.lines.length === 0) return { discountVnd: 0, applied: [] };

    const productIds = [...new Set(input.lines.map((l) => l.productId))];
    const products = await this.prisma.product.findMany({
      where: { id: { in: productIds } },
      select: { id: true, categoryId: true },
    });
    const catOf = new Map(products.map((p) => [p.id, p.categoryId]));

    const campaigns = await this.prisma.campaign.findMany({
      where: {
        isActive: true,
        type: { in: AUTO_TYPES },
        OR: [{ storeId: null }, { storeId: input.storeId }],
        AND: [
          { OR: [{ startsAt: null }, { startsAt: { lte: now } }] },
          { OR: [{ endsAt: null }, { endsAt: { gte: now } }] },
        ],
      },
      orderBy: { priority: 'desc' },
    });
    const live = campaigns.filter((c) => this.isLiveNow(c, now));
    if (live.length === 0) return { discountVnd: 0, applied: [] };

    // Enforce usage caps before applying. Drop globally-exhausted campaigns,
    // and — when the customer is known — ones the user already hit their
    // per-user limit on. recordUsage() re-checks atomically in the order tx;
    // this just stops exhausted campaigns from quoting a discount.
    const eligible = await this.filterByUsage(live, input.customerId);
    if (eligible.length === 0) return { discountVnd: 0, applied: [] };

    const applied = new Map<string, AppliedCampaign>();
    const add = (c: Campaign, amount: number) => {
      if (amount <= 0) return;
      const prev = applied.get(c.id);
      applied.set(c.id, {
        id: c.id,
        name: c.name,
        type: c.type,
        discountVnd: (prev?.discountVnd ?? 0) + amount,
      });
    };
    let total = 0;

    // 1. Per-line best discount (PRODUCT/CATEGORY/FLASH/HAPPY_HOUR).
    const lineCampaigns = eligible.filter((c) => LINE_TYPES.includes(c.type));
    for (const line of input.lines) {
      const cat = catOf.get(line.productId) ?? null;
      let bestDiscount = 0;
      let best: Campaign | null = null;
      for (const c of lineCampaigns) {
        if (!this.matchesLine(c, line.productId, cat)) continue;
        const d = this.lineDiscount(c, line.lineTotalVnd);
        if (d > bestDiscount) {
          bestDiscount = d;
          best = c;
        }
      }
      if (best) {
        total += bestDiscount;
        add(best, bestDiscount);
      }
    }

    // 2. Buy X Get Y (cart-level).
    for (const c of eligible.filter((c) => c.type === 'BUY_X_GET_Y')) {
      const d = this.bxgyDiscount(c, input.lines, catOf);
      if (d > 0) {
        total += d;
        add(c, d);
      }
    }

    // 3. Order-level customer-targeted (best single one).
    const orderCampaigns = eligible.filter((c) => ORDER_TYPES.includes(c.type));
    if (orderCampaigns.length > 0 && input.customerId) {
      const ctx = await this.customerContext(input.customerId);
      let bestDiscount = 0;
      let best: Campaign | null = null;
      for (const c of orderCampaigns) {
        if (!this.orderApplies(c, ctx, now)) continue;
        const d = this.orderDiscount(c, input.subtotalVnd, ctx);
        if (d > bestDiscount) {
          bestDiscount = d;
          best = c;
        }
      }
      if (best) {
        total += bestDiscount;
        add(best, bestDiscount);
      }
    }

    return { discountVnd: total, applied: [...applied.values()] };
  }

  /** Drops campaigns that have hit their global `usageLimit`, and (when the
   *  customer is known) ones the user has hit `perUserLimit` on. */
  private async filterByUsage(
    live: Campaign[],
    customerId?: string,
  ): Promise<Campaign[]> {
    const underGlobal = live.filter(
      (c) => c.usageLimit == null || c.usedCount < c.usageLimit,
    );
    if (!customerId) return underGlobal;
    const limited = underGlobal.filter(
      (c) => c.perUserLimit != null && c.perUserLimit > 0,
    );
    if (limited.length === 0) return underGlobal;
    const counts = await this.prisma.campaignRedemption.groupBy({
      by: ['campaignId'],
      where: { userId: customerId, campaignId: { in: limited.map((c) => c.id) } },
      _count: { campaignId: true },
    });
    const usedByUser = new Map(
      counts.map((r) => [r.campaignId, r._count.campaignId]),
    );
    return underGlobal.filter((c) => {
      if (c.perUserLimit == null || c.perUserLimit <= 0) return true;
      return (usedByUser.get(c.id) ?? 0) < c.perUserLimit;
    });
  }

  /**
   * Records that the given campaigns were applied to an order — the
   * AUTHORITATIVE limit check (mirrors CouponsService.recordRedemption).
   * `evaluate` only reads counters, so concurrent checkouts could both quote
   * an exhausted campaign; a per-campaign advisory lock serialises redemptions
   * of the same campaign within the order tx, re-checks both caps, and throws
   * (rolling back the order) before incrementing usedCount.
   */
  async recordUsage(args: {
    campaignIds: string[];
    userId: string;
    orderId: string;
    tx: Prisma.TransactionClient;
  }): Promise<void> {
    for (const campaignId of args.campaignIds) {
      await args.tx
        .$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${campaignId}, 0))`;
      const c = await args.tx.campaign.findUnique({
        where: { id: campaignId },
        select: { usageLimit: true, perUserLimit: true, usedCount: true },
      });
      if (!c) continue;
      if (c.usageLimit != null && c.usedCount >= c.usageLimit) {
        throw new BadRequestException({
          code: 'CAMPAIGN_LIMIT_REACHED',
          message: 'Khuyến mãi đã hết lượt.',
        });
      }
      if (c.perUserLimit != null && c.perUserLimit > 0) {
        const used = await args.tx.campaignRedemption.count({
          where: { campaignId, userId: args.userId },
        });
        if (used >= c.perUserLimit) {
          throw new BadRequestException({
            code: 'CAMPAIGN_USER_LIMIT',
            message: 'Bạn đã dùng hết lượt khuyến mãi này.',
          });
        }
      }
      await args.tx.campaignRedemption.create({
        data: { campaignId, userId: args.userId, orderId: args.orderId },
      });
      await args.tx.campaign.update({
        where: { id: campaignId },
        data: { usedCount: { increment: 1 } },
      });
    }
  }

  /** Reverses any campaign usage recorded for an order — deletes the
   *  redemption row(s) and decrements usedCount. Used when an order is
   *  cancelled or its payment can't be initiated, so a campaign's per-user /
   *  global allowance isn't burned on an order that never completed. */
  async reverseUsage(
    orderId: string,
    db?: Prisma.TransactionClient,
  ): Promise<void> {
    const run = async (tx: Prisma.TransactionClient): Promise<void> => {
      const rows = await tx.campaignRedemption.findMany({
        where: { orderId },
        select: { campaignId: true },
      });
      if (rows.length === 0) return;
      // Delete first; a concurrent reverse (double-cancel race) gets count 0
      // from the row-locked deleteMany and skips the decrement, so usedCount
      // can never drop twice for one row.
      const del = await tx.campaignRedemption.deleteMany({ where: { orderId } });
      if (del.count === 0) return;
      for (const r of rows) {
        await tx.campaign.update({
          where: { id: r.campaignId },
          data: { usedCount: { decrement: 1 } },
        });
      }
    };
    // Run in the caller's tx (atomic with the order's status change) when
    // provided, otherwise in its own transaction.
    return db ? run(db) : this.prisma.$transaction(run);
  }

  /** HAPPY_HOUR only runs inside its daily time + weekday window (VN time). */
  private isLiveNow(c: Campaign, now: Date): boolean {
    if (c.type !== 'HAPPY_HOUR') return true;
    const cfg = (c.config ?? {}) as Record<string, unknown>;
    const start = parseHHMM(cfg.startTime);
    const end = parseHHMM(cfg.endTime);
    if (start == null || end == null) return false;
    const { minutes, day } = vnNow(now);
    const inWindow =
      start <= end
        ? minutes >= start && minutes < end
        : minutes >= start || minutes < end; // overnight window
    const days = Array.isArray(cfg.daysOfWeek)
      ? (cfg.daysOfWeek as number[])
      : [];
    const dayOk = days.length === 0 || days.includes(day);
    return inWindow && dayOk;
  }

  private matchesLine(
    c: Campaign,
    productId: string,
    categoryId: string | null,
  ): boolean {
    switch (c.type) {
      case 'PRODUCT_DISCOUNT': {
        const cfg = (c.config ?? {}) as Record<string, unknown>;
        const pids = asStrArray(cfg.productIds);
        return pids.includes(productId);
      }
      case 'CATEGORY_DISCOUNT': {
        const cfg = (c.config ?? {}) as Record<string, unknown>;
        const cids = asStrArray(cfg.categoryIds);
        return categoryId != null && cids.includes(categoryId);
      }
      case 'FLASH_SALE':
      case 'HAPPY_HOUR':
        return this.scopeMatches(c, productId, categoryId);
      default:
        return false;
    }
  }

  /** Scope match for whole-menu-capable types (empty scope = whole menu). */
  private scopeMatches(
    c: Campaign,
    productId: string,
    categoryId: string | null,
  ): boolean {
    const cfg = (c.config ?? {}) as Record<string, unknown>;
    const pids = asStrArray(cfg.productIds);
    const cids = asStrArray(cfg.categoryIds);
    if (pids.length === 0 && cids.length === 0) return true;
    if (pids.includes(productId)) return true;
    return categoryId != null && cids.includes(categoryId);
  }

  private lineDiscount(c: Campaign, lineTotalVnd: number): number {
    const cfg = (c.config ?? {}) as Record<string, unknown>;
    const value = Number(cfg.value) || 0;
    if (value <= 0) return 0;
    if (cfg.kind === 'FIXED') return Math.min(Math.round(value), lineTotalVnd);
    return Math.min(lineTotalVnd, Math.round((lineTotalVnd * value) / 100));
  }

  /** Buy X Get Y: every (buyQty+getQty) qualifying units yields getQty
   *  discounted units (cheapest first), at getDiscountPct% off (default 100). */
  private bxgyDiscount(
    c: Campaign,
    lines: CartLine[],
    catOf: Map<string, string | null>,
  ): number {
    const cfg = (c.config ?? {}) as Record<string, unknown>;
    const buyQty = Math.floor(Number(cfg.buyQty) || 0);
    const getQty = Math.floor(Number(cfg.getQty) || 0);
    if (buyQty <= 0 || getQty <= 0) return 0;
    const getPct =
      cfg.getDiscountPct != null ? Number(cfg.getDiscountPct) : 100;
    if (getPct <= 0) return 0;

    const units: number[] = [];
    for (const line of lines) {
      const cat = catOf.get(line.productId) ?? null;
      if (!this.scopeMatches(c, line.productId, cat)) continue;
      if (line.quantity <= 0) continue;
      const unit = line.lineTotalVnd / line.quantity;
      for (let i = 0; i < line.quantity; i++) units.push(unit);
    }
    const bundle = buyQty + getQty;
    if (units.length < bundle) return 0;
    const freeCount = Math.floor(units.length / bundle) * getQty;
    units.sort((a, b) => a - b); // cheapest units get the discount
    let d = 0;
    for (let i = 0; i < freeCount && i < units.length; i++) {
      d += (units[i] * getPct) / 100;
    }
    return Math.round(d);
  }

  private orderApplies(c: Campaign, ctx: CustomerContext, now: Date): boolean {
    const cfg = (c.config ?? {}) as Record<string, unknown>;
    switch (c.type) {
      case 'FIRST_ORDER':
        return ctx.orderCount === 0;
      case 'BIRTHDAY': {
        if (!ctx.birthday) return false;
        const windowDays =
          cfg.windowDays != null ? Number(cfg.windowDays) : 7;
        return withinBirthday(ctx.birthday, now, windowDays);
      }
      case 'REACTIVATION': {
        if (!ctx.lastOrderAt) return false; // never ordered → not re-activation
        const inactiveDays = Number(cfg.inactiveDays) || 60;
        const elapsed = now.getTime() - ctx.lastOrderAt.getTime();
        return elapsed > inactiveDays * 86_400_000;
      }
      case 'MEMBERSHIP_BENEFIT':
        return ctx.tier != null && tierValue(cfg, ctx.tier) > 0;
      default:
        return false;
    }
  }

  private orderDiscount(
    c: Campaign,
    subtotalVnd: number,
    ctx: CustomerContext,
  ): number {
    const cfg = (c.config ?? {}) as Record<string, unknown>;
    // MEMBERSHIP_BENEFIT reads the % (or ₫) for the customer's current tier.
    const value =
      c.type === 'MEMBERSHIP_BENEFIT'
        ? (ctx.tier ? tierValue(cfg, ctx.tier) : 0)
        : Number(cfg.value) || 0;
    if (value <= 0) return 0;
    const minSub = Number(cfg.minSubtotal) || 0;
    if (subtotalVnd < minSub) return 0;
    if (cfg.kind === 'FIXED') return Math.min(Math.round(value), subtotalVnd);
    return Math.min(subtotalVnd, Math.round((subtotalVnd * value) / 100));
  }

  private async customerContext(customerId: string): Promise<CustomerContext> {
    const [user, agg] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: customerId },
        select: { birthday: true, membershipTier: true },
      }),
      this.prisma.order.aggregate({
        where: { customerId },
        _count: { _all: true },
        _max: { createdAt: true },
      }),
    ]);
    return {
      orderCount: agg._count._all,
      lastOrderAt: agg._max.createdAt ?? null,
      birthday: user?.birthday ?? null,
      tier: user?.membershipTier ?? null,
    };
  }

  // ── Admin CRUD ────────────────────────────────────────────────────────────

  list(type?: string) {
    const where: Prisma.CampaignWhereInput = {};
    if (type && (Object.values(CampaignType) as string[]).includes(type)) {
      where.type = type as CampaignType;
    }
    return this.prisma.campaign.findMany({
      where,
      orderBy: [{ isActive: 'desc' }, { createdAt: 'desc' }],
    });
  }

  get(id: string) {
    return this.prisma.campaign.findUnique({ where: { id } });
  }

  create(dto: CreateCampaignDto) {
    return this.prisma.campaign.create({
      data: {
        type: dto.type,
        name: dto.name.trim(),
        isActive: dto.isActive ?? true,
        priority: dto.priority ?? 0,
        stackable: dto.stackable ?? true,
        startsAt: dto.startsAt ? new Date(dto.startsAt) : null,
        endsAt: dto.endsAt ? new Date(dto.endsAt) : null,
        config: dto.config as Prisma.InputJsonValue,
        storeId: dto.storeId ?? null,
        usageLimit: dto.usageLimit ?? null,
        perUserLimit: dto.perUserLimit ?? null,
      },
    });
  }

  update(id: string, dto: UpdateCampaignDto) {
    const data: Prisma.CampaignUpdateInput = {};
    if (dto.name !== undefined) data.name = dto.name.trim();
    if (dto.isActive !== undefined) data.isActive = dto.isActive;
    if (dto.priority !== undefined) data.priority = dto.priority;
    if (dto.stackable !== undefined) data.stackable = dto.stackable;
    if (dto.startsAt !== undefined) {
      data.startsAt = dto.startsAt ? new Date(dto.startsAt) : null;
    }
    if (dto.endsAt !== undefined) {
      data.endsAt = dto.endsAt ? new Date(dto.endsAt) : null;
    }
    if (dto.config !== undefined) {
      data.config = dto.config as Prisma.InputJsonValue;
    }
    if (dto.storeId !== undefined) data.storeId = dto.storeId || null;
    if (dto.usageLimit !== undefined) data.usageLimit = dto.usageLimit;
    if (dto.perUserLimit !== undefined) data.perUserLimit = dto.perUserLimit;
    return this.prisma.campaign.update({ where: { id }, data });
  }

  remove(id: string) {
    return this.prisma.campaign.delete({ where: { id } });
  }
}

function asStrArray(v: unknown): string[] {
  return Array.isArray(v) ? (v as string[]) : [];
}

/** Reads the per-tier value from a MEMBERSHIP_BENEFIT config
 *  (`{ tierValues: { SILVER, GOLD, PLATINUM } }`). */
function tierValue(cfg: Record<string, unknown>, tier: MembershipTier): number {
  const tv = (cfg.tierValues ?? {}) as Record<string, unknown>;
  return Number(tv[tier]) || 0;
}

function vnNow(now: Date): { minutes: number; day: number } {
  const vn = new Date(now.getTime() + 7 * 60 * 60 * 1000); // UTC+7
  return {
    minutes: vn.getUTCHours() * 60 + vn.getUTCMinutes(),
    day: vn.getUTCDay(),
  };
}

function parseHHMM(s: unknown): number | null {
  if (typeof s !== 'string') return null;
  const m = /^(\d{1,2}):(\d{2})$/.exec(s.trim());
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/** True when `now` (VN date) falls within ±windowDays of the birthday's
 *  month/day, ignoring the year (handles the Dec↔Jan wrap-around). */
function withinBirthday(birthday: Date, now: Date, windowDays: number): boolean {
  const vnNowDate = new Date(now.getTime() + 7 * 60 * 60 * 1000);
  const dayOfYear = (d: Date): number => {
    const start = Date.UTC(d.getUTCFullYear(), 0, 1);
    const cur = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
    return Math.floor((cur - start) / 86_400_000);
  };
  const bdayUtc = new Date(
    Date.UTC(2020, birthday.getUTCMonth(), birthday.getUTCDate()),
  );
  const nowRef = new Date(
    Date.UTC(2020, vnNowDate.getUTCMonth(), vnNowDate.getUTCDate()),
  );
  let diff = Math.abs(dayOfYear(nowRef) - dayOfYear(bdayUtc));
  if (diff > 182) diff = 365 - diff; // wrap-around
  return diff <= windowDays;
}

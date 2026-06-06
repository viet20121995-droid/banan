import { Injectable } from '@nestjs/common';
import { Campaign, CampaignType, Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import { CreateCampaignDto, UpdateCampaignDto } from './dto';

/** Campaign types the checkout engine auto-applies (no code needed). */
const AUTO_TYPES: CampaignType[] = [
  'PRODUCT_DISCOUNT',
  'CATEGORY_DISCOUNT',
  'FLASH_SALE',
  'HAPPY_HOUR',
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

@Injectable()
export class PromotionsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Evaluate active automatic-discount campaigns against a cart. Pure read —
   * the caller subtracts the returned discount. Each line gets at most the
   * single best matching campaign (no double-discount on one product); the
   * totals per campaign are summed for display/reporting.
   */
  async evaluate(input: {
    lines: CartLine[];
    storeId: string;
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

    const applied = new Map<string, AppliedCampaign>();
    let total = 0;
    for (const line of input.lines) {
      const cat = catOf.get(line.productId) ?? null;
      let bestDiscount = 0;
      let best: Campaign | null = null;
      for (const c of live) {
        if (!this.matchesLine(c, line.productId, cat)) continue;
        const d = this.lineDiscount(c, line.lineTotalVnd);
        if (d > bestDiscount) {
          bestDiscount = d;
          best = c;
        }
      }
      if (best && bestDiscount > 0) {
        total += bestDiscount;
        const prev = applied.get(best.id);
        applied.set(best.id, {
          id: best.id,
          name: best.name,
          type: best.type,
          discountVnd: (prev?.discountVnd ?? 0) + bestDiscount,
        });
      }
    }
    return { discountVnd: total, applied: [...applied.values()] };
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
    const cfg = (c.config ?? {}) as Record<string, unknown>;
    const pids = Array.isArray(cfg.productIds) ? (cfg.productIds as string[]) : [];
    const cids = Array.isArray(cfg.categoryIds)
      ? (cfg.categoryIds as string[])
      : [];
    switch (c.type) {
      case 'PRODUCT_DISCOUNT':
        return pids.includes(productId);
      case 'CATEGORY_DISCOUNT':
        return categoryId != null && cids.includes(categoryId);
      case 'FLASH_SALE':
      case 'HAPPY_HOUR':
        if (pids.length === 0 && cids.length === 0) return true; // whole menu
        if (pids.includes(productId)) return true;
        return categoryId != null && cids.includes(categoryId);
      default:
        return false;
    }
  }

  private lineDiscount(c: Campaign, lineTotalVnd: number): number {
    const cfg = (c.config ?? {}) as Record<string, unknown>;
    const value = Number(cfg.value) || 0;
    if (value <= 0) return 0;
    if (cfg.kind === 'FIXED') {
      return Math.min(Math.round(value), lineTotalVnd);
    }
    // PERCENT (default)
    return Math.min(lineTotalVnd, Math.round((lineTotalVnd * value) / 100));
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

function vnNow(now: Date): { minutes: number; day: number } {
  const vn = new Date(now.getTime() + 7 * 60 * 60 * 1000); // UTC+7
  return { minutes: vn.getUTCHours() * 60 + vn.getUTCMinutes(), day: vn.getUTCDay() };
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

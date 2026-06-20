import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Coupon, CouponType, Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

export interface CouponValidation {
  coupon: Coupon;
  discountVnd: number;
  appliesToDelivery: boolean;
}

export interface WalletCoupon {
  code: string;
  type: CouponType;
  value: string;
  minSubtotal: string | null;
  label: string | null;
  startsAt: string;
  endsAt: string;
}

@Injectable()
export class CouponsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Validates a coupon code against `subtotal` (and optionally a user, for
   * per-user limit checks). Throws on any rule failure with a stable
   * error code so the customer UI can localize the message.
   */
  async validate(args: {
    code: string;
    subtotalVnd: number;
    deliveryFeeVnd: number;
    userId: string;
    storeId?: string;
  }): Promise<CouponValidation> {
    const coupon = await this.prisma.coupon.findUnique({
      where: { code: args.code.toUpperCase() },
    });
    if (!coupon || !coupon.isActive) {
      throw new BadRequestException({
        code: 'COUPON_INVALID',
        message: 'This coupon is not valid.',
      });
    }
    // Store-scoped coupons only work at their owning store. Chain-wide
    // coupons (storeId null) work everywhere.
    if (coupon.storeId !== null && args.storeId !== undefined && coupon.storeId !== args.storeId) {
      throw new BadRequestException({
        code: 'COUPON_WRONG_STORE',
        message: 'This coupon is not valid at this store.',
      });
    }
    const now = new Date();
    if (now < coupon.startsAt || now > coupon.endsAt) {
      throw new BadRequestException({
        code: 'COUPON_EXPIRED',
        message: 'This coupon is not active right now.',
      });
    }
    if (coupon.maxRedemptions !== null && coupon.redemptions >= coupon.maxRedemptions) {
      throw new BadRequestException({
        code: 'COUPON_LIMIT_REACHED',
        message: 'This coupon has been fully claimed.',
      });
    }
    if (coupon.minSubtotal !== null) {
      const min = Number(coupon.minSubtotal.toString());
      if (args.subtotalVnd < min) {
        throw new BadRequestException({
          code: 'COUPON_MIN_SUBTOTAL',
          message: `Minimum subtotal of ${min.toLocaleString('vi-VN')}₫ not met.`,
        });
      }
    }
    if (coupon.perUserLimit > 0) {
      const used = await this.prisma.couponRedemption.count({
        where: { couponId: coupon.id, userId: args.userId },
      });
      if (used >= coupon.perUserLimit) {
        throw new BadRequestException({
          code: 'COUPON_USER_LIMIT',
          message: 'You have already used this coupon.',
        });
      }
    }

    return {
      coupon,
      discountVnd: this.computeDiscount(coupon, args.subtotalVnd, args.deliveryFeeVnd),
      appliesToDelivery: coupon.type === 'FREE_DELIVERY',
    };
  }

  /**
   * Records a redemption when an order is created — the AUTHORITATIVE limit
   * check. `validate()` runs before the order transaction opens and only reads
   * counters, so two concurrent checkouts could both pass it and overshoot the
   * global `maxRedemptions` / per-user limit (each creates a row with a
   * distinct orderId, so the [couponId,userId,orderId] unique never trips).
   *
   * We close that race with a per-coupon transaction advisory lock: all
   * redemptions of the same coupon serialize for the duration of the order
   * transaction (contention is limited to simultaneous uses of that one
   * coupon), so the re-checks below see committed state and cannot be
   * overshot. Throwing here rolls back the whole order.
   */
  async recordRedemption(args: {
    couponId: string;
    userId: string;
    orderId: string;
    tx: Prisma.TransactionClient;
  }): Promise<void> {
    await args.tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${args.couponId}, 0))`;

    const coupon = await args.tx.coupon.findUniqueOrThrow({
      where: { id: args.couponId },
      select: { maxRedemptions: true, perUserLimit: true, redemptions: true },
    });
    if (coupon.maxRedemptions !== null && coupon.redemptions >= coupon.maxRedemptions) {
      throw new BadRequestException({
        code: 'COUPON_LIMIT_REACHED',
        message: 'This coupon has been fully claimed.',
      });
    }
    if (coupon.perUserLimit > 0) {
      const used = await args.tx.couponRedemption.count({
        where: { couponId: args.couponId, userId: args.userId },
      });
      if (used >= coupon.perUserLimit) {
        throw new BadRequestException({
          code: 'COUPON_USER_LIMIT',
          message: 'You have already used this coupon.',
        });
      }
    }

    await args.tx.couponRedemption.create({
      data: {
        couponId: args.couponId,
        userId: args.userId,
        orderId: args.orderId,
      },
    });
    await args.tx.coupon.update({
      where: { id: args.couponId },
      data: { redemptions: { increment: 1 } },
    });
  }

  /** Reverses any coupon redemption recorded for an order — deletes the
   *  redemption row(s) and decrements the coupon counter. Used when an order
   *  is cancelled or its payment can't be initiated, so the coupon use isn't
   *  burned on an order that never went through. Each row maps to exactly one
   *  prior increment, so the decrement stays balanced. */
  async reverseRedemption(orderId: string, db?: Prisma.TransactionClient): Promise<void> {
    const run = async (tx: Prisma.TransactionClient): Promise<void> => {
      const rows = await tx.couponRedemption.findMany({
        where: { orderId },
        select: { couponId: true },
      });
      if (rows.length === 0) return;
      // Delete first; the deleteMany takes row locks, so a concurrent reverse
      // (e.g. a double-cancel race) finds nothing and gets count 0 — we then
      // skip the decrement, so the counter can never drop twice for one row.
      const del = await tx.couponRedemption.deleteMany({ where: { orderId } });
      if (del.count === 0) return;
      for (const r of rows) {
        await tx.coupon.update({
          where: { id: r.couponId },
          data: { redemptions: { decrement: 1 } },
        });
      }
    };
    // Run in the caller's tx (atomic with the order's status change) when
    // provided, otherwise in its own transaction.
    return db ? run(db) : this.prisma.$transaction(run);
  }

  /** Voucher wallet for a customer — active coupons grouped into
   *  available / used / expired. Coupons are shared codes (not assigned), so
   *  "available" = active + in-window + not exhausted (globally or per user). */
  async listForCustomer(userId: string) {
    const now = new Date();
    const [coupons, redemptions] = await Promise.all([
      this.prisma.coupon.findMany({
        where: { isActive: true },
        orderBy: { endsAt: 'asc' },
      }),
      this.prisma.couponRedemption.findMany({
        where: { userId },
        include: { coupon: true },
        orderBy: { createdAt: 'desc' },
      }),
    ]);
    const usedByCoupon = new Map<string, number>();
    for (const r of redemptions) {
      usedByCoupon.set(r.couponId, (usedByCoupon.get(r.couponId) ?? 0) + 1);
    }
    const available: WalletCoupon[] = [];
    const expired: WalletCoupon[] = [];
    for (const c of coupons) {
      if (c.endsAt < now) {
        expired.push(this.walletView(c));
        continue;
      }
      if (c.startsAt > now) continue; // not started yet
      const globalExhausted = c.maxRedemptions != null && c.redemptions >= c.maxRedemptions;
      const userExhausted = (usedByCoupon.get(c.id) ?? 0) >= c.perUserLimit;
      if (globalExhausted || userExhausted) continue;
      available.push(this.walletView(c));
    }
    const used = redemptions.map((r) => ({
      ...this.walletView(r.coupon),
      usedAt: r.createdAt.toISOString(),
    }));
    return { available, used, expired };
  }

  private walletView(c: Coupon): WalletCoupon {
    return {
      code: c.code,
      type: c.type,
      value: c.value.toString(),
      minSubtotal: c.minSubtotal?.toString() ?? null,
      label: c.label,
      startsAt: c.startsAt.toISOString(),
      endsAt: c.endsAt.toISOString(),
    };
  }

  // ───────────────────────── Merchant management ─────────────────────────

  /**
   * Coupons a store manager can see: their own store-scoped coupons plus
   * chain-wide ones (read-only for them). Admin (storeId null) sees all.
   */
  async listForStore(storeId: string | null) {
    const where: Prisma.CouponWhereInput =
      storeId === null ? {} : { OR: [{ storeId }, { storeId: null }] };
    const coupons = await this.prisma.coupon.findMany({
      where,
      orderBy: { createdAt: 'desc' },
    });
    return coupons.map((c) => this.view(c, storeId));
  }

  async createForStore(
    storeId: string | null,
    dto: {
      code: string;
      type: CouponType;
      value: number;
      minSubtotalVnd?: number;
      startsAt: string;
      endsAt: string;
      maxRedemptions?: number | null;
      perUserLimit: number;
      label?: string;
    },
  ) {
    const start = new Date(dto.startsAt);
    const end = new Date(dto.endsAt);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      throw new BadRequestException({ code: 'COUPON_BAD_DATES' });
    }
    if (end <= start) {
      throw new BadRequestException({
        code: 'COUPON_BAD_DATES',
        message: 'End date must be after the start date.',
      });
    }
    try {
      const created = await this.prisma.coupon.create({
        data: {
          code: dto.code.trim().toUpperCase(),
          type: dto.type,
          value: new Prisma.Decimal(dto.value),
          minSubtotal:
            dto.minSubtotalVnd && dto.minSubtotalVnd > 0
              ? new Prisma.Decimal(dto.minSubtotalVnd)
              : null,
          startsAt: start,
          endsAt: end,
          maxRedemptions: dto.maxRedemptions && dto.maxRedemptions > 0 ? dto.maxRedemptions : null,
          perUserLimit: dto.perUserLimit,
          isActive: true,
          storeId: storeId ?? null,
          label: dto.label?.trim() || null,
        },
      });
      return this.view(created, storeId);
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new BadRequestException({
          code: 'COUPON_CODE_TAKEN',
          message: 'That code is already in use.',
        });
      }
      throw e;
    }
  }

  /** Toggle / edit limited mutable fields. Merchants can only touch their
   *  own store's coupons. */
  async updateForStore(
    storeId: string | null,
    id: string,
    patch: {
      isActive?: boolean;
      endsAt?: string;
      maxRedemptions?: number | null;
      label?: string;
    },
  ) {
    const coupon = await this.owned(storeId, id);
    const data: Prisma.CouponUpdateInput = {};
    if (patch.isActive !== undefined) data.isActive = patch.isActive;
    if (patch.label !== undefined) data.label = patch.label.trim() || null;
    if (patch.endsAt !== undefined) {
      const end = new Date(patch.endsAt);
      if (Number.isNaN(end.getTime())) {
        throw new BadRequestException({ code: 'COUPON_BAD_DATES' });
      }
      data.endsAt = end;
    }
    if (patch.maxRedemptions !== undefined) {
      data.maxRedemptions =
        patch.maxRedemptions && patch.maxRedemptions > 0 ? patch.maxRedemptions : null;
    }
    const updated = await this.prisma.coupon.update({
      where: { id: coupon.id },
      data,
    });
    return this.view(updated, storeId);
  }

  private async owned(storeId: string | null, id: string): Promise<Coupon> {
    const coupon = await this.prisma.coupon.findUnique({ where: { id } });
    if (!coupon) {
      throw new NotFoundException({ code: 'COUPON_NOT_FOUND' });
    }
    // A store manager may only mutate their own store's coupons (not
    // chain-wide ones). Admin (null) may mutate anything.
    if (storeId !== null && coupon.storeId !== storeId) {
      throw new ForbiddenException({ code: 'COUPON_NOT_YOURS' });
    }
    return coupon;
  }

  private view(c: Coupon, viewerStoreId: string | null) {
    return {
      id: c.id,
      code: c.code,
      type: c.type,
      value: Number(c.value.toString()),
      minSubtotalVnd: c.minSubtotal === null ? null : Number(c.minSubtotal.toString()),
      startsAt: c.startsAt.toISOString(),
      endsAt: c.endsAt.toISOString(),
      maxRedemptions: c.maxRedemptions,
      redemptions: c.redemptions,
      perUserLimit: c.perUserLimit,
      isActive: c.isActive,
      label: c.label,
      chainWide: c.storeId === null,
      // Merchants can't edit chain-wide coupons; admins can edit everything.
      editable: viewerStoreId === null || c.storeId === viewerStoreId,
    };
  }

  private computeDiscount(coupon: Coupon, subtotalVnd: number, deliveryFeeVnd: number): number {
    const value = Number(coupon.value.toString());
    switch (coupon.type satisfies CouponType) {
      case 'PERCENT':
        return Math.min(subtotalVnd, Math.round((subtotalVnd * value) / 100));
      case 'FIXED':
        return Math.min(subtotalVnd, Math.round(value));
      case 'FREE_DELIVERY':
        return Math.round(deliveryFeeVnd);
    }
  }
}

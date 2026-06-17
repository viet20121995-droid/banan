import { BadRequestException, Injectable } from '@nestjs/common';
import {
  LoyaltyEvent,
  LoyaltyEventType,
  MembershipTier,
  Order,
  Prisma,
} from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

/**
 * Loyalty configuration. Tweakable in one place — eventually moves to a
 * `LoyaltyConfig` table when admin UI lands.
 */
const CONFIG = {
  /** 1 Micho per N VND spent on the order subtotal. */
  earnRatePerVnd: 50_000,
  /** Legacy: 1 point redeems for N VND off (kept for the loyalty view). */
  redemptionValueVnd: 100,
  /** Members holding more than this many Micho get an automatic order
   *  discount of [michoDiscountRate]. */
  michoDiscountThreshold: 100,
  michoDiscountRate: 0.05,
  tiers: {
    bronze: 0,
    silver: 500,
    gold: 2_000,
    platinum: 5_000,
  },
};

@Injectable()
export class LoyaltyService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Awards earn-points for a completed order. Idempotent — re-completing the
   * same order won't double-award (we check for an existing EARN event).
   */
  async earnFor(
    order: Order,
    db?: Prisma.TransactionClient,
  ): Promise<LoyaltyEvent | null> {
    const subtotal = Number(order.subtotal.toString());
    const points = Math.floor(subtotal / CONFIG.earnRatePerVnd);
    if (points <= 0) return null;

    const run = async (tx: Prisma.TransactionClient): Promise<LoyaltyEvent> => {
      // When run standalone, serialise concurrent earns for this order with a
      // per-order advisory lock + re-check. When `db` is the caller's tx, the
      // transition is already status-guarded (runs once), so no lock needed.
      if (!db) {
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${order.id}, 0))`;
      }
      const existing = await tx.loyaltyEvent.findFirst({
        where: { orderId: order.id, type: 'EARN' },
      });
      if (existing) return existing;

      // Atomic increment (not read-then-absolute-write) so a concurrent
      // earn/redeem/adjust on the SAME user can't lose this update.
      const updated = await tx.user.update({
        where: { id: order.customerId },
        data: { pointsBalance: { increment: points } },
        select: { pointsBalance: true },
      });
      const balanceAfter = updated.pointsBalance;
      const event = await tx.loyaltyEvent.create({
        data: {
          userId: order.customerId,
          orderId: order.id,
          type: 'EARN',
          delta: points,
          balanceAfter,
          reason: `Earned on order ${order.code}`,
        },
      });
      await tx.user.update({
        where: { id: order.customerId },
        data: { membershipTier: tierFor(balanceAfter) },
      });
      return event;
    };
    return db ? run(db) : this.prisma.$transaction(run);
  }

  /**
   * Tx-aware redemption: deducts `points` inside the caller's transaction so
   * the order row + the REDEEM event + the balance update all commit
   * atomically. The caller is responsible for capping `points` to the order
   * value; this re-checks the balance to stay race-safe.
   */
  async redeemWithinTx(
    tx: Prisma.TransactionClient,
    args: { userId: string; orderId: string; orderCode: string; points: number },
  ): Promise<void> {
    if (args.points <= 0) return;
    // Atomic guarded decrement: only deduct if the balance still covers it.
    // A conditional updateMany serialises against concurrent redeems on the
    // same user (Postgres re-checks the predicate under the row lock), so the
    // balance can never be overdrawn or lost-updated.
    const res = await tx.user.updateMany({
      where: { id: args.userId, pointsBalance: { gte: args.points } },
      data: { pointsBalance: { decrement: args.points } },
    });
    if (res.count === 0) {
      throw new BadRequestException({
        code: 'LOYALTY_INSUFFICIENT_POINTS',
        message: 'Bạn không có đủ điểm Micho.',
      });
    }
    const user = await tx.user.findUniqueOrThrow({
      where: { id: args.userId },
      select: { pointsBalance: true },
    });
    const balanceAfter = user.pointsBalance;
    await tx.loyaltyEvent.create({
      data: {
        userId: args.userId,
        orderId: args.orderId,
        type: 'REDEEM',
        delta: -args.points,
        balanceAfter,
        reason: `Redeemed against order ${args.orderCode}`,
      },
    });
    await tx.user.update({
      where: { id: args.userId },
      data: { membershipTier: tierFor(balanceAfter) },
    });
  }

  /** Refunds the points if a paid order is cancelled after the redeem event.
   *  Accepts the caller's `db`/tx so the reversal commits atomically with the
   *  order's status change. */
  async refundRedemption(
    orderId: string,
    db: Prisma.TransactionClient = this.prisma,
  ): Promise<void> {
    const redeem = await db.loyaltyEvent.findFirst({
      where: { orderId, type: 'REDEEM' },
    });
    if (!redeem) return;
    await this.recordEvent(
      {
        userId: redeem.userId,
        orderId,
        type: 'ADJUSTMENT',
        delta: -redeem.delta, // delta was negative, so this restores the points
        reason: 'Reversed redemption — order cancelled',
      },
      db,
    );
  }

  /**
   * Manual points adjustment by store staff (goodwill, birthday gift,
   * compensation for a bad order). `delta` may be negative. Recorded as an
   * ADJUSTMENT event so it shows in the customer's loyalty history.
   */
  async adminAdjust(args: {
    userId: string;
    delta: number;
    reason: string;
  }): Promise<LoyaltyEvent> {
    if (!Number.isInteger(args.delta) || args.delta === 0) {
      throw new BadRequestException({
        code: 'LOYALTY_INVALID_DELTA',
        message: 'Adjustment must be a non-zero whole number.',
      });
    }
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: args.userId },
      select: { pointsBalance: true },
    });
    if (user.pointsBalance + args.delta < 0) {
      throw new BadRequestException({
        code: 'LOYALTY_NEGATIVE_BALANCE',
        message: `Customer only has ${user.pointsBalance} Micho.`,
      });
    }
    return this.recordEvent({
      userId: args.userId,
      type: 'ADJUSTMENT',
      delta: args.delta,
      reason: args.reason,
    });
  }

  async getMyLoyalty(userId: string) {
    const [user, recent] = await this.prisma.$transaction([
      this.prisma.user.findUniqueOrThrow({
        where: { id: userId },
        select: {
          pointsBalance: true,
          membershipTier: true,
          birthday: true,
        },
      }),
      this.prisma.loyaltyEvent.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 30,
      }),
    ]);
    return {
      tier: user.membershipTier,
      balance: user.pointsBalance,
      birthday: user.birthday?.toISOString() ?? null,
      history: recent,
      thresholds: CONFIG.tiers,
      earnRatePerVnd: CONFIG.earnRatePerVnd,
      redemptionValueVnd: CONFIG.redemptionValueVnd,
    };
  }

  private async recordEvent(
    args: {
      userId: string;
      orderId?: string;
      type: LoyaltyEventType;
      delta: number;
      reason: string;
    },
    db?: Prisma.TransactionClient,
  ): Promise<LoyaltyEvent> {
    const run = async (tx: Prisma.TransactionClient): Promise<LoyaltyEvent> => {
      // Atomic balance mutation (no lost-update). For a NEGATIVE delta use a
      // guarded conditional decrement so two concurrent negative adjustments
      // can't both pass a pre-check and drive the balance below zero
      // (adminAdjust's pre-check alone is racy).
      if (args.delta < 0) {
        const res = await tx.user.updateMany({
          where: { id: args.userId, pointsBalance: { gte: -args.delta } },
          data: { pointsBalance: { increment: args.delta } },
        });
        if (res.count === 0) {
          throw new BadRequestException({
            code: 'LOYALTY_NEGATIVE_BALANCE',
            message: 'Số dư điểm không đủ.',
          });
        }
      } else {
        await tx.user.update({
          where: { id: args.userId },
          data: { pointsBalance: { increment: args.delta } },
        });
      }
      const refreshed = await tx.user.findUniqueOrThrow({
        where: { id: args.userId },
        select: { pointsBalance: true },
      });
      const balanceAfter = refreshed.pointsBalance;
      const event = await tx.loyaltyEvent.create({
        data: {
          userId: args.userId,
          orderId: args.orderId,
          type: args.type,
          delta: args.delta,
          balanceAfter,
          reason: args.reason,
        },
      });
      await tx.user.update({
        where: { id: args.userId },
        data: { membershipTier: tierFor(balanceAfter) },
      });
      return event;
    };
    return db ? run(db) : this.prisma.$transaction(run);
  }
}

function tierFor(balance: number): MembershipTier {
  if (balance >= CONFIG.tiers.platinum) return 'PLATINUM';
  if (balance >= CONFIG.tiers.gold) return 'GOLD';
  if (balance >= CONFIG.tiers.silver) return 'SILVER';
  return 'BRONZE';
}

/** Re-export for tests / consumers. */
export const LOYALTY_CONFIG = CONFIG;

// Tiny no-op so unused-import linters don't complain — this file uses Prisma
// types directly above.
export type { Prisma };

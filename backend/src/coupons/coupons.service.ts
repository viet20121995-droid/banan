import { BadRequestException, Injectable } from '@nestjs/common';
import { Coupon, CouponType, Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

export interface CouponValidation {
  coupon: Coupon;
  discountVnd: number;
  appliesToDelivery: boolean;
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
    const now = new Date();
    if (now < coupon.startsAt || now > coupon.endsAt) {
      throw new BadRequestException({
        code: 'COUPON_EXPIRED',
        message: 'This coupon is not active right now.',
      });
    }
    if (
      coupon.maxRedemptions !== null &&
      coupon.redemptions >= coupon.maxRedemptions
    ) {
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

  /** Records a redemption when an order is created — increments the counter. */
  async recordRedemption(args: {
    couponId: string;
    userId: string;
    orderId: string;
    tx: Prisma.TransactionClient;
  }): Promise<void> {
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

  private computeDiscount(
    coupon: Coupon,
    subtotalVnd: number,
    deliveryFeeVnd: number,
  ): number {
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

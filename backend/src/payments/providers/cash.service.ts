import { BadRequestException, Injectable } from '@nestjs/common';
import { FulfillmentType, Prisma } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';

/**
 * Cash on receipt — at the counter for pickup, or to the courier for delivery
 * (COD). Off unless `COD_ENABLED=true`; see `validateAllowed` below.
 *
 * No external provider call — we just record an AUTHORIZED Payment row that
 * is flipped to CAPTURED when the merchant marks the order COMPLETED. That
 * row is also how a fully discounted order (total <= 0) settles, which is why
 * the methods below stay reachable while the customer-facing gate is closed.
 */
@Injectable()
export class CashPaymentService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Cash on receipt (counter for pickup, COD for delivery). Off by default:
   * the storefront is online-prepaid only, and hiding the option in the app
   * is not enforcement — a direct API call could still book a COD order.
   * Set `COD_ENABLED=true` to accept cash again; no code change needed.
   *
   * Note: this gate is only consulted when the CUSTOMER picks cash. A fully
   * discounted order (total <= 0) records a CASH payment row internally after
   * validation and is unaffected.
   */
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  validateAllowed(_fulfillment: FulfillmentType): void {
    if (process.env.COD_ENABLED !== 'true') {
      throw new BadRequestException({
        code: 'COD_DISABLED',
        message: 'Hiện chỉ nhận thanh toán online.',
      });
    }
  }

  async initiate(args: {
    orderId: string;
    amount: string;
    currency: string;
  }): Promise<{ paymentId: string }> {
    const payment = await this.prisma.payment.create({
      data: {
        orderId: args.orderId,
        provider: 'CASH',
        // No external ref; use the order id as a per-provider unique key.
        providerRef: args.orderId,
        amount: args.amount,
        currency: args.currency,
        status: 'AUTHORIZED',
      },
    });
    return { paymentId: payment.id };
  }

  // `db` lets the caller run this inside its transaction so the cash-payment
  // state change commits atomically with the order status; defaults to the
  // base client for standalone use.
  async markCollected(orderId: string, db: Prisma.TransactionClient = this.prisma): Promise<void> {
    await db.payment.updateMany({
      where: { orderId, provider: 'CASH', status: 'AUTHORIZED' },
      data: { status: 'CAPTURED' },
    });
  }

  async voidUncollected(
    orderId: string,
    db: Prisma.TransactionClient = this.prisma,
  ): Promise<void> {
    await db.payment.updateMany({
      where: { orderId, provider: 'CASH', status: { in: ['AUTHORIZED', 'INITIATED'] } },
      data: { status: 'VOIDED' },
    });
  }

  /** Cash refunds happen at the counter — synchronous, no provider call. */
  // eslint-disable-next-line @typescript-eslint/require-await
  async refund(): Promise<{ completed: true; providerRef?: undefined }> {
    return { completed: true };
  }
}

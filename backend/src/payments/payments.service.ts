import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import {
  Order,
  OrderItem,
  OrderStatus,
  Payment,
  PaymentProvider,
  Prisma,
  Refund,
} from '@prisma/client';

import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

import type { PaymentInstructions } from './dto/payment-instructions';
import { CashPaymentService } from './providers/cash.service';
import { MoMoPaymentService } from './providers/momo.service';
import { NinePayPaymentService } from './providers/ninepay.service';
import { StripePaymentService } from './providers/stripe.service';

interface InitiateArgs {
  order: Order & { items: OrderItem[] };
  paymentMethod: PaymentProvider;
  customerIp: string;
}

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cash: CashPaymentService,
    private readonly stripe: StripePaymentService,
    private readonly momo: MoMoPaymentService,
    private readonly ninepay: NinePayPaymentService,
    private readonly realtime: RealtimeGateway,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * Centralised online-capture path for all redirect providers (Stripe /
   * MoMo / 9Pay), called from their webhook/IPN handlers. Two guards the
   * per-provider `updateMany` was missing:
   *   1. status gate — only an INITIATED/AUTHORIZED payment can be captured,
   *      so a replayed or late webhook can't resurrect a VOIDED/REFUNDED one;
   *   2. amount cross-check — the provider-reported paid amount must equal
   *      what we charged (signature stops forgery; this stops misconfig /
   *      partial-payment edge cases).
   * On success it emits realtime + a customer "payment captured" notification,
   * which the raw `updateMany` did not do.
   */
  async applyCapture(args: {
    provider: PaymentProvider;
    providerRef: string;
    paidAmountVnd?: number | null;
    currency?: string;
    payload: object;
  }): Promise<void> {
    const payment = await this.prisma.payment.findFirst({
      where: { provider: args.provider, providerRef: args.providerRef },
    });
    if (!payment) {
      this.logger.warn(`Capture for unknown ${args.provider} ref ${args.providerRef} — ignored`);
      return;
    }

    // Validate the provider-reported settlement BEFORE acting on it. These
    // checks are status-independent (provider amount/currency vs what we
    // charged), so they guard BOTH the normal capture and the stranded-VOIDED
    // auto-refund path below. Fail closed on any mismatch.
    if (args.currency && args.currency.toUpperCase() !== payment.currency.toUpperCase()) {
      this.logger.error(
        `Currency mismatch on payment ${payment.id}: provider reports ${args.currency}, expected ${payment.currency} — refusing to capture`,
      );
      return;
    }
    const expected = Math.round(Number(payment.amount.toString()));
    // A redirect provider must report a settlement amount we can cross-check.
    // Treat a missing amount as a refusal rather than capturing an unverified
    // sum (Stripe's session.amount_total is nullable).
    if (args.paidAmountVnd == null) {
      this.logger.error(
        `No provider amount on payment ${payment.id} (expected ${expected}) — refusing to capture`,
      );
      return;
    }
    if (Math.round(args.paidAmountVnd) !== expected) {
      this.logger.error(
        `Amount mismatch on payment ${payment.id}: provider reports ${args.paidAmountVnd}, expected ${expected} — refusing to capture`,
      );
      return;
    }

    // Normal path: an open payment is captured.
    if (payment.status === 'INITIATED' || payment.status === 'AUTHORIZED') {
      const res = await this.prisma.payment.updateMany({
        where: { id: payment.id, status: { in: ['INITIATED', 'AUTHORIZED'] } },
        data: { status: 'CAPTURED', rawPayload: args.payload },
      });
      if (res.count === 0) return; // lost a race to a concurrent webhook

      // A late webhook can capture a payment on an order the customer already
      // cancelled (the cancel ran first and saw no captured payment to refund).
      // The money is now at the provider against a cancelled order, so auto-open
      // a refund for staff and skip the celebratory "payment captured" ping.
      const order = await this.prisma.order.findUnique({
        where: { id: payment.orderId },
        select: { id: true, status: true, storeId: true },
      });
      if (order && (order.status === 'CANCELLED' || order.status === 'REFUNDED')) {
        this.logger.error(
          `Captured ${args.provider} payment ${payment.id} on ${order.status} order ${order.id} — opening auto-refund`,
        );
        await this.openAutoRefund(payment, order.storeId);
        return;
      }
      await this.onCaptured(payment.orderId);
      return;
    }

    // Stranded-capture path: we already VOIDED this payment locally because the
    // order was cancelled (onOrderCancelled voids still-INITIATED online
    // payments) — but the provider actually collected the money and sent a late
    // "paid" callback. Without this branch applyCapture returned early and the
    // funds sat at the provider with no CAPTURED record and no Refund, invisible
    // to staff. Flip VOIDED → CAPTURED (the money is real; amount/currency were
    // verified above) and auto-open a refund.
    if (payment.status === 'VOIDED') {
      const res = await this.prisma.payment.updateMany({
        where: { id: payment.id, status: 'VOIDED' },
        data: { status: 'CAPTURED', rawPayload: args.payload },
      });
      if (res.count === 0) return; // lost a race
      const order = await this.prisma.order.findUnique({
        where: { id: payment.orderId },
        select: { id: true, status: true, storeId: true },
      });
      this.logger.error(
        `Stranded ${args.provider} capture on VOIDED payment ${payment.id} (order ${payment.orderId}) — flipped to CAPTURED, opening auto-refund`,
      );
      await this.openAutoRefund(payment, order?.storeId ?? null);
      return;
    }

    // Any other terminal state (CAPTURED replay / REFUNDED / FAILED): ignore.
    this.logger.warn(
      `Ignoring capture for payment ${payment.id} in terminal state ${payment.status}`,
    );
  }

  /**
   * Opens a staff-actionable refund for money captured against an order that
   * should not have stayed paid — a cancelled/refunded order, or a payment we
   * had locally VOIDED. Idempotent: the partial unique index on
   * Refund(orderId, paymentId) for non-REJECTED rows means a concurrent
   * cancel-path refund creation collides with P2002, which we treat as a no-op.
   */
  private async openAutoRefund(payment: Payment, storeId: string | null): Promise<void> {
    const already = await this.prisma.refund.findFirst({
      where: { orderId: payment.orderId, paymentId: payment.id },
    });
    if (already) return;
    try {
      await this.prisma.refund.create({
        data: {
          orderId: payment.orderId,
          paymentId: payment.id,
          amount: payment.amount,
          reason: 'Auto: payment captured on a cancelled/voided order',
          status: 'REQUESTED',
          requestedById: 'system',
        },
      });
      if (storeId) {
        this.realtime.emit([`store:${storeId}`], 'refund.auto_requested', {
          orderId: payment.orderId,
          paymentId: payment.id,
          at: new Date().toISOString(),
        });
      }
    } catch (e) {
      // Cancel path's refund row won the race (partial unique index). The
      // duplicate is a no-op. Standalone create (not an interactive tx), so
      // catching is safe.
      if (!(e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002')) {
        throw e;
      }
    }
  }

  /** Marks a still-open payment FAILED (expired / declined webhook). */
  async applyFailure(args: {
    provider: PaymentProvider;
    providerRef: string;
    payload: object;
  }): Promise<void> {
    await this.prisma.payment.updateMany({
      where: {
        provider: args.provider,
        providerRef: args.providerRef,
        status: { in: ['INITIATED', 'AUTHORIZED'] },
      },
      data: { status: 'FAILED', rawPayload: args.payload },
    });
  }

  /**
   * Settles an async provider refund when its "refund succeeded" webhook
   * arrives (e.g. Stripe `charge.refunded`). RefundsService.process() parks
   * such refunds in PROCESSING with the provider refund id as providerRef;
   * here we match that row and drive it to COMPLETED, then mirror the order
   * and payment to REFUNDED. Without this, async refunds stayed PROCESSING
   * forever (the money left the provider but the order never showed REFUNDED).
   *
   * Idempotent: a replayed webhook (refund already COMPLETED, or none found)
   * is a no-op, and the status-guarded updateMany wins at most once.
   */
  async applyRefundSettled(args: {
    provider: PaymentProvider;
    providerRef: string;
    payload?: object;
  }): Promise<void> {
    const refund = await this.prisma.refund.findFirst({
      where: {
        providerRef: args.providerRef,
        status: { in: ['APPROVED', 'PROCESSING'] },
      },
    });
    if (!refund) {
      this.logger.warn(
        `Refund webhook for unknown/already-settled ${args.provider} ref ${args.providerRef} — ignored`,
      );
      return;
    }
    const res = await this.prisma.refund.updateMany({
      where: { id: refund.id, status: { in: ['APPROVED', 'PROCESSING'] } },
      data: { status: 'COMPLETED' },
    });
    if (res.count === 0) return; // lost a race to a concurrent webhook
    // Mirror onto the order + payment so customer/merchant see REFUNDED.
    await this.prisma.order.updateMany({
      where: { id: refund.orderId, status: { in: ['CANCELLED', 'COMPLETED'] } },
      data: { status: 'REFUNDED' satisfies OrderStatus },
    });
    if (refund.paymentId) {
      await this.prisma.payment.updateMany({
        where: { id: refund.paymentId, status: 'CAPTURED' },
        data: { status: 'REFUNDED' },
      });
    }
    this.realtime.emit([`order:${refund.orderId}`], 'refund.updated', {
      refundId: refund.id,
      orderId: refund.orderId,
      status: 'COMPLETED',
      at: new Date().toISOString(),
    });
  }

  /** Emits realtime + notifies the customer that an online payment landed. */
  private async onCaptured(orderId: string): Promise<void> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: {
        id: true,
        code: true,
        customerId: true,
        storeId: true,
        kitchenId: true,
      },
    });
    if (!order) return;
    const rooms = [`order:${order.id}`, `user:${order.customerId}`, `store:${order.storeId}`];
    if (order.kitchenId) rooms.push(`kitchen:${order.kitchenId}`);
    this.realtime.emit(rooms, 'order.payment_captured', {
      orderId: order.id,
      code: order.code,
      at: new Date().toISOString(),
    });
    await this.notifications.sendToUser(
      order.customerId,
      {
        type: 'payment.captured',
        title: 'Thanh toán thành công 🎉',
        body: `Đơn ${order.code} đã được thanh toán. Cảm ơn bạn!`,
      },
      { orderId: order.id, code: order.code },
    );
  }

  /** Validates the chosen method against the fulfillment type and config.
   *  Called BEFORE the order transaction, so an online provider that isn't
   *  configured is rejected up-front — otherwise `initiate()` would return a
   *  configurationError only AFTER the order committed (stock / coupon /
   *  campaign / gift-card already consumed on an unpayable PENDING order). */
  validate(method: PaymentProvider, fulfillment: 'PICKUP' | 'DELIVERY'): void {
    if (method === 'CASH') {
      this.cash.validateAllowed(fulfillment);
      return;
    }
    const enabled =
      method === 'STRIPE'
        ? this.stripe.enabled
        : method === 'MOMO'
          ? this.momo.enabled
          : method === 'NINEPAY'
            ? this.ninepay.enabled
            : false;
    if (!enabled) {
      throw new BadRequestException({
        code: 'PAYMENT_PROVIDER_UNAVAILABLE',
        message: 'Phương thức thanh toán này hiện chưa khả dụng.',
      });
    }
  }

  async initiate(args: InitiateArgs): Promise<PaymentInstructions> {
    const { order, paymentMethod } = args;
    const amount = order.total.toString();
    const currency = order.currency;

    switch (paymentMethod) {
      case 'CASH': {
        const { paymentId } = await this.cash.initiate({
          orderId: order.id,
          amount,
          currency,
        });
        return { provider: 'CASH', paymentId, payAtPickup: true };
      }
      case 'STRIPE': {
        const result = await this.stripe.initiate({
          orderId: order.id,
          orderCode: order.code,
          amount,
          currency,
          items: order.items.map((i) => ({
            name: i.productName,
            variantLabel: i.variantLabel ?? undefined,
            quantity: i.quantity,
            unitAmount: Number(i.unitPrice),
          })),
        });
        if ('configurationError' in result) {
          return {
            provider: 'STRIPE',
            paymentId: '',
            configurationError: result.configurationError,
          };
        }
        return {
          provider: 'STRIPE',
          paymentId: result.paymentId,
          redirectUrl: result.redirectUrl,
        };
      }
      case 'MOMO': {
        const result = await this.momo.initiate({
          orderId: order.id,
          orderCode: order.code,
          amount,
          currency,
        });
        if ('configurationError' in result) {
          return {
            provider: 'MOMO',
            paymentId: '',
            configurationError: result.configurationError,
          };
        }
        return {
          provider: 'MOMO',
          paymentId: result.paymentId,
          redirectUrl: result.redirectUrl,
        };
      }
      case 'NINEPAY': {
        const result = await this.ninepay.initiate({
          orderId: order.id,
          orderCode: order.code,
          amount,
          currency,
        });
        if ('configurationError' in result) {
          return {
            provider: 'NINEPAY',
            paymentId: '',
            configurationError: result.configurationError,
          };
        }
        return {
          provider: 'NINEPAY',
          paymentId: result.paymentId,
          redirectUrl: result.redirectUrl,
        };
      }
      default:
        throw new BadRequestException({
          code: 'UNSUPPORTED_PAYMENT_METHOD',
          message: `Unsupported payment method: ${paymentMethod}`,
        });
    }
  }

  /** Called from OrdersService when an order completes. Cash orders flip to CAPTURED. */
  async onOrderCompleted(
    orderId: string,
    db: Prisma.TransactionClient = this.prisma,
  ): Promise<void> {
    await this.cash.markCollected(orderId, db);
  }

  /**
   * Called from OrdersService when an order is cancelled. Voids what we can,
   * and returns the captured payments that need refund processing — the
   * caller (orders → refunds) creates the corresponding Refund rows.
   */
  async onOrderCancelled(
    orderId: string,
    db: Prisma.TransactionClient = this.prisma,
  ): Promise<{ capturedPayments: Payment[] }> {
    await this.cash.voidUncollected(orderId, db);
    await db.payment.updateMany({
      where: {
        orderId,
        provider: { in: ['STRIPE', 'PAYOS', 'MOMO', 'NINEPAY'] },
        status: 'INITIATED',
      },
      data: { status: 'VOIDED' },
    });

    // Anything still CAPTURED (Stripe/MoMo/9Pay, or CASH after collection)
    // needs a refund — return so the caller can drive the Refund flow.
    const capturedPayments = await db.payment.findMany({
      where: { orderId, status: 'CAPTURED' },
    });
    return { capturedPayments };
  }

  /**
   * Executes the provider-side refund for an approved Refund. Returns
   * `{ completed: true }` for synchronous providers (CASH); `false` for
   * async ones (Stripe/MoMo/9Pay) — caller marks the refund PROCESSING
   * and waits for the webhook / manual reconciliation.
   */
  async executeRefund(refund: Refund): Promise<{ completed: boolean; providerRef?: string }> {
    if (!refund.paymentId) {
      throw new BadRequestException({
        code: 'REFUND_NO_PAYMENT',
        message: 'Refund is not linked to a payment.',
      });
    }
    const payment = await this.prisma.payment.findUnique({
      where: { id: refund.paymentId },
    });
    if (!payment) throw new NotFoundException({ code: 'PAYMENT_NOT_FOUND' });

    switch (payment.provider) {
      case 'CASH':
        return this.cash.refund();
      case 'STRIPE':
        return this.stripe.refund({
          paymentRawPayload: payment.rawPayload,
          amountMinorUnits: Math.round(Number(refund.amount.toString())),
        });
      case 'PAYOS':
        // Legacy PayOS payments (pre-9Pay) — the provider was removed; refunds
        // are reconciled manually via bank transfer, the same posture PayOS had.
        return { completed: false };
      case 'MOMO':
        return this.momo.refund();
      case 'NINEPAY':
        return this.ninepay.refund();
      default:
        throw new BadRequestException({ code: 'UNSUPPORTED_PROVIDER' });
    }
  }

  /**
   * RefundsService calls this after marking a refund COMPLETED — flips the
   * underlying Payment to REFUNDED so order detail shows the right state.
   */
  async markPaymentRefunded(paymentId: string): Promise<void> {
    await this.prisma.payment.update({
      where: { id: paymentId },
      data: { status: 'REFUNDED' },
    });
  }

  /** Returns the most recent payment for an order — used by RefundsService. */
  async findLatestCaptured(orderId: string): Promise<Payment | null> {
    return this.prisma.payment.findFirst({
      where: { orderId, status: 'CAPTURED' },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Maps a provider's `providerRef` back to our orderId — used by browser
   * return handlers (e.g. 9Pay) to deep-link the customer straight to their
   * order. Returns null if no matching payment exists.
   */
  async findOrderIdByRef(provider: PaymentProvider, providerRef: string): Promise<string | null> {
    const payment = await this.prisma.payment.findFirst({
      where: { provider, providerRef },
      select: { orderId: true },
    });
    return payment?.orderId ?? null;
  }
}

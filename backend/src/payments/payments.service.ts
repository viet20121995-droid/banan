import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  Order,
  OrderItem,
  OrderStatus,
  Payment,
  PaymentProvider,
  Refund,
} from '@prisma/client';

import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

import type { PaymentInstructions } from './dto/payment-instructions';
import { CashPaymentService } from './providers/cash.service';
import { MoMoPaymentService } from './providers/momo.service';
import { PayOSPaymentService } from './providers/payos.service';
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
    private readonly payos: PayOSPaymentService,
    private readonly momo: MoMoPaymentService,
    private readonly realtime: RealtimeGateway,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * Centralised online-capture path for all redirect providers (Stripe /
   * PayOS / MoMo), called from their webhook/IPN handlers. Two guards the
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
    payload: object;
  }): Promise<void> {
    const payment = await this.prisma.payment.findFirst({
      where: { provider: args.provider, providerRef: args.providerRef },
    });
    if (!payment) {
      this.logger.warn(
        `Capture for unknown ${args.provider} ref ${args.providerRef} — ignored`,
      );
      return;
    }
    if (payment.status !== 'INITIATED' && payment.status !== 'AUTHORIZED') {
      this.logger.warn(
        `Ignoring capture for payment ${payment.id} in terminal state ${payment.status}`,
      );
      return;
    }
    if (args.paidAmountVnd != null) {
      const expected = Math.round(Number(payment.amount.toString()));
      if (Math.round(args.paidAmountVnd) !== expected) {
        this.logger.error(
          `Amount mismatch on payment ${payment.id}: provider reports ${args.paidAmountVnd}, expected ${expected} — refusing to capture`,
        );
        return;
      }
    }
    const res = await this.prisma.payment.updateMany({
      where: { id: payment.id, status: { in: ['INITIATED', 'AUTHORIZED'] } },
      data: { status: 'CAPTURED', rawPayload: args.payload },
    });
    if (res.count === 0) return; // lost a race to a concurrent webhook

    // A late webhook can capture a payment on an order the customer already
    // cancelled (the cancel ran first and saw no captured payment to refund).
    // The money is now at the provider against a cancelled order, so auto-open
    // a refund for staff to process instead of leaving a stranded CAPTURED
    // payment, and skip the celebratory "payment captured" customer ping.
    const order = await this.prisma.order.findUnique({
      where: { id: payment.orderId },
      select: { id: true, status: true, storeId: true },
    });
    if (order && (order.status === 'CANCELLED' || order.status === 'REFUNDED')) {
      this.logger.error(
        `Captured ${args.provider} payment ${payment.id} on ${order.status} order ${order.id} — opening auto-refund`,
      );
      const already = await this.prisma.refund.findFirst({
        where: { orderId: order.id, paymentId: payment.id },
      });
      if (!already) {
        await this.prisma.refund.create({
          data: {
            orderId: order.id,
            paymentId: payment.id,
            amount: payment.amount,
            reason: `Auto: payment captured after order ${order.status}`,
            status: 'REQUESTED',
            requestedById: 'system',
          },
        });
        this.realtime.emit([`store:${order.storeId}`], 'refund.auto_requested', {
          orderId: order.id,
          paymentId: payment.id,
          at: new Date().toISOString(),
        });
      }
      return;
    }
    await this.onCaptured(payment.orderId);
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
    const rooms = [
      `order:${order.id}`,
      `user:${order.customerId}`,
      `store:${order.storeId}`,
    ];
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

  /** Validates the chosen method against the fulfillment type and config. */
  validate(method: PaymentProvider, fulfillment: 'PICKUP' | 'DELIVERY'): void {
    if (method === 'CASH') this.cash.validateAllowed(fulfillment);
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
      case 'PAYOS': {
        const result = await this.payos.initiate({
          orderId: order.id,
          orderCode: order.code,
          amount,
          currency,
        });
        if ('configurationError' in result) {
          return {
            provider: 'PAYOS',
            paymentId: '',
            configurationError: result.configurationError,
          };
        }
        return {
          provider: 'PAYOS',
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
      default:
        throw new BadRequestException({
          code: 'UNSUPPORTED_PAYMENT_METHOD',
          message: `Unsupported payment method: ${paymentMethod}`,
        });
    }
  }

  /** Called from OrdersService when an order completes. Cash orders flip to CAPTURED. */
  async onOrderCompleted(orderId: string): Promise<void> {
    await this.cash.markCollected(orderId);
  }

  /**
   * Called from OrdersService when an order is cancelled. Voids what we can,
   * and returns the captured payments that need refund processing — the
   * caller (orders → refunds) creates the corresponding Refund rows.
   */
  async onOrderCancelled(orderId: string): Promise<{ capturedPayments: Payment[] }> {
    await this.cash.voidUncollected(orderId);
    await this.prisma.payment.updateMany({
      where: {
        orderId,
        provider: { in: ['STRIPE', 'PAYOS', 'MOMO'] },
        status: 'INITIATED',
      },
      data: { status: 'VOIDED' },
    });

    // Anything still CAPTURED (Stripe/PayOS/MoMo, or CASH after collection)
    // needs a refund — return so the caller can drive the Refund flow.
    const capturedPayments = await this.prisma.payment.findMany({
      where: { orderId, status: 'CAPTURED' },
    });
    return { capturedPayments };
  }

  /**
   * Executes the provider-side refund for an approved Refund. Returns
   * `{ completed: true }` for synchronous providers (CASH); `false` for
   * async ones (Stripe/PayOS/MoMo) — caller marks the refund PROCESSING
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
        return this.payos.refund();
      case 'MOMO':
        return this.momo.refund();
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
}

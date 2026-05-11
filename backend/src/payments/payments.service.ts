import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Order, OrderItem, Payment, PaymentProvider, Refund } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import type { PaymentInstructions } from './dto/payment-instructions';
import { CashPaymentService } from './providers/cash.service';
import { MoMoPaymentService } from './providers/momo.service';
import { StripePaymentService } from './providers/stripe.service';
import { VNPayPaymentService } from './providers/vnpay.service';

interface InitiateArgs {
  order: Order & { items: OrderItem[] };
  paymentMethod: PaymentProvider;
  customerIp: string;
}

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cash: CashPaymentService,
    private readonly stripe: StripePaymentService,
    private readonly vnpay: VNPayPaymentService,
    private readonly momo: MoMoPaymentService,
  ) {}

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
      case 'VNPAY': {
        const result = await this.vnpay.initiate({
          orderId: order.id,
          orderCode: order.code,
          amount,
          currency,
          customerIp: args.customerIp,
        });
        if ('configurationError' in result) {
          return {
            provider: 'VNPAY',
            paymentId: '',
            configurationError: result.configurationError,
          };
        }
        return {
          provider: 'VNPAY',
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
        provider: { in: ['STRIPE', 'VNPAY', 'MOMO'] },
        status: 'INITIATED',
      },
      data: { status: 'VOIDED' },
    });

    // Anything still CAPTURED (Stripe/VNPay/MoMo, or CASH after collection)
    // needs a refund — return so the caller can drive the Refund flow.
    const capturedPayments = await this.prisma.payment.findMany({
      where: { orderId, status: 'CAPTURED' },
    });
    return { capturedPayments };
  }

  /**
   * Executes the provider-side refund for an approved Refund. Returns
   * `{ completed: true }` for synchronous providers (CASH); `false` for
   * async ones (Stripe/VNPay/MoMo) — caller marks the refund PROCESSING
   * and waits for the webhook.
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
      case 'VNPAY':
        return this.vnpay.refund();
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

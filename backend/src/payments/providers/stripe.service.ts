import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import Stripe from 'stripe';

import { PrismaService } from '../../prisma/prisma.service';

interface CheckoutItem {
  name: string;
  quantity: number;
  /** Unit price in the order's currency (VND has no decimals). */
  unitAmount: number;
  variantLabel?: string;
}

@Injectable()
export class StripePaymentService {
  private readonly logger = new Logger(StripePaymentService.name);
  private readonly stripe?: Stripe;
  private readonly webhookSecret?: string;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    const key = config.get<string>('STRIPE_SECRET_KEY');
    if (key && key.length > 0) {
      this.stripe = new Stripe(key);
      this.logger.log('Stripe configured');
    } else {
      this.logger.warn(
        'STRIPE_SECRET_KEY not set — Stripe payments will return a configuration error.',
      );
    }
    this.webhookSecret = config.get<string>('STRIPE_WEBHOOK_SECRET');
  }

  get enabled(): boolean {
    return !!this.stripe;
  }

  async initiate(args: {
    orderId: string;
    orderCode: string;
    amount: string;
    currency: string;
    items: CheckoutItem[];
  }): Promise<
    | { paymentId: string; redirectUrl: string }
    | { configurationError: string }
  > {
    if (!this.stripe) {
      return {
        configurationError:
          'Stripe is not configured. Add STRIPE_SECRET_KEY to backend/.env and restart.',
      };
    }
    const successBase =
      this.config.get<string>('STRIPE_SUCCESS_URL') ??
      'http://localhost:8081/payments/return/stripe';
    const cancelUrl =
      this.config.get<string>('STRIPE_CANCEL_URL') ??
      'http://localhost:8081/checkout';

    // Charge the ACTUAL order total (after delivery fee, campaign/coupon/points/
    // gift-card adjustments) as a single line item, so Stripe's amount_total
    // equals Payment.amount (= order.total). Reconstructing line items from
    // unit prices would charge the wrong sum and fail the capture amount-check.
    // The itemised breakdown already lives in the app's own order view.
    const itemSummary = args.items
      .map((i) => `${i.quantity}× ${i.variantLabel ? `${i.name} (${i.variantLabel})` : i.name}`)
      .join(', ')
      .slice(0, 480);
    // VND has 0 decimals, so the integer VND total IS the amount in minor units.
    const session = await this.stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency: args.currency.toLowerCase(),
            unit_amount: Math.round(Number(args.amount)),
            product_data: {
              name: `Đơn hàng Banan #${args.orderCode}`,
              description: itemSummary || undefined,
            },
          },
        },
      ],
      success_url:
        `${successBase}?session_id={CHECKOUT_SESSION_ID}&order_code=${args.orderCode}`,
      cancel_url: cancelUrl,
      metadata: { orderId: args.orderId, orderCode: args.orderCode },
    });

    const payment = await this.prisma.payment.create({
      data: {
        orderId: args.orderId,
        provider: 'STRIPE',
        providerRef: session.id,
        amount: args.amount,
        currency: args.currency,
        status: 'INITIATED',
        rawPayload: { sessionId: session.id, sessionUrl: session.url },
      },
    });

    return { paymentId: payment.id, redirectUrl: session.url! };
  }

  /**
   * Verifies the Stripe-Signature header against `STRIPE_WEBHOOK_SECRET` and
   * marks the matching Payment row as CAPTURED on `checkout.session.completed`.
   * Stripe is the authority — never trust the success_url alone.
   */
  async handleWebhook(
    rawBody: Buffer,
    signature: string,
  ): Promise<
    | { kind: 'captured'; providerRef: string; paidAmountVnd: number | null; payload: object }
    | { kind: 'failed'; providerRef: string; payload: object }
    | { kind: 'ignored' }
  > {
    if (!this.stripe || !this.webhookSecret) {
      this.logger.warn('Stripe webhook hit but provider is not configured');
      return { kind: 'ignored' };
    }
    let event: Stripe.Event;
    try {
      event = this.stripe.webhooks.constructEvent(
        rawBody,
        signature,
        this.webhookSecret,
      );
    } catch (e) {
      this.logger.error('Stripe webhook signature verification failed', e as Error);
      throw new Error('invalid_signature');
    }

    if (event.type === 'checkout.session.completed') {
      const session = event.data.object as Stripe.Checkout.Session;
      // VND has no decimals, so amount_total IS the VND figure.
      return {
        kind: 'captured',
        providerRef: session.id,
        paidAmountVnd: session.amount_total ?? null,
        payload: event as unknown as object,
      };
    } else if (event.type === 'checkout.session.expired') {
      const session = event.data.object as Stripe.Checkout.Session;
      return {
        kind: 'failed',
        providerRef: session.id,
        payload: event as unknown as object,
      };
    }
    return { kind: 'ignored' };
  }

  /**
   * Issues a Stripe refund against the original PaymentIntent recorded in
   * the Payment's rawPayload (set by the webhook on capture).
   *
   * Returns `completed: true` if Stripe reports `succeeded` synchronously;
   * otherwise `completed: false` and the caller marks the refund PROCESSING
   * until `charge.refunded` arrives via webhook.
   */
  async refund(args: {
    paymentRawPayload: Prisma.JsonValue | null;
    amountMinorUnits: number;
  }): Promise<{ completed: boolean; providerRef?: string }> {
    if (!this.stripe) throw new Error('Stripe not configured');
    const paymentIntent = extractPaymentIntentId(args.paymentRawPayload);
    if (!paymentIntent) {
      throw new Error('Cannot refund — no Stripe PaymentIntent on payment');
    }
    const refund = await this.stripe.refunds.create({
      payment_intent: paymentIntent,
      amount: args.amountMinorUnits,
      reason: 'requested_by_customer',
    });
    return {
      completed: refund.status === 'succeeded',
      providerRef: refund.id,
    };
  }
}

function extractPaymentIntentId(payload: Prisma.JsonValue | null): string | null {
  if (!payload || typeof payload !== 'object') return null;
  // Prisma.JsonObject — runtime check.
  const obj = payload as Record<string, unknown>;
  // Webhook event shape: { data: { object: { payment_intent: '...' } } }.
  const data = obj['data'];
  if (data && typeof data === 'object') {
    const session = (data as Record<string, unknown>)['object'];
    if (session && typeof session === 'object') {
      const pi = (session as Record<string, unknown>)['payment_intent'];
      if (typeof pi === 'string') return pi;
    }
  }
  // Direct `paymentIntent` field — set by initiate() if needed.
  const pi = obj['paymentIntent'];
  return typeof pi === 'string' ? pi : null;
}

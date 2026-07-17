import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Logger,
  Post,
  Query,
  RawBodyRequest,
  Req,
  Res,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiTags } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import type { Request, Response } from 'express';

import { Public } from '../auth/decorators/public.decorator';

import { PaymentsService } from './payments.service';
import { MoMoPaymentService } from './providers/momo.service';
import { NinePayPaymentService } from './providers/ninepay.service';
import { StripePaymentService } from './providers/stripe.service';

// Webhook + IPN endpoints are called by upstream providers and can fire in
// bursts, so @SkipThrottle() is applied PER-METHOD to the server-to-server
// webhook/IPN POSTs only — browser-facing GET return endpoints stay throttled.
// Signature/checksum verification is the real gate on the webhooks.
@ApiTags('payments')
@Controller({ path: 'payments', version: '1' })
export class PaymentsController {
  private readonly logger = new Logger(PaymentsController.name);

  constructor(
    private readonly stripe: StripePaymentService,
    private readonly momo: MoMoPaymentService,
    private readonly ninepay: NinePayPaymentService,
    private readonly payments: PaymentsService,
    private readonly config: ConfigService,
  ) {}

  /** Stripe-Signature is required for verification. Stripe sends raw JSON. */
  @SkipThrottle()
  @Public()
  @Post('stripe/webhook')
  @HttpCode(HttpStatus.OK)
  async stripeWebhook(
    @Req() req: RawBodyRequest<Request>,
    @Headers('stripe-signature') signature: string,
  ): Promise<{ received: true }> {
    if (!req.rawBody) {
      this.logger.warn('Stripe webhook missing raw body');
      return { received: true };
    }
    const r = await this.stripe.handleWebhook(req.rawBody, signature);
    if (r.kind === 'captured') {
      await this.payments.applyCapture({
        provider: 'STRIPE',
        providerRef: r.providerRef,
        paidAmountVnd: r.paidAmountVnd,
        currency: r.currency,
        payload: r.payload,
      });
    } else if (r.kind === 'failed') {
      await this.payments.applyFailure({
        provider: 'STRIPE',
        providerRef: r.providerRef,
        payload: r.payload,
      });
    } else if (r.kind === 'refunded') {
      await this.payments.applyRefundSettled({
        provider: 'STRIPE',
        providerRef: r.providerRef,
        payload: r.payload,
      });
    }
    return { received: true };
  }

  /**
   * 9Pay redirects the customer's browser back here after checkout (GET with
   * `result` + `checksum` query params). UX only — we verify, look up the
   * order so we can deep-link to it, and bounce to the customer app. The DB
   * state is set authoritatively by the IPN below.
   */
  @Public()
  @Get('ninepay/return')
  async ninepayReturn(@Query() query: Record<string, string>, @Res() res: Response): Promise<void> {
    const customerBase =
      this.config.get<string>('CUSTOMER_APP_BASE_URL') ?? 'http://localhost:8081';
    const verified = this.ninepay.verifyResult(query);
    // The return carries the same checksum-signed result as the IPN, so treat it
    // as authoritative too: capture on 'paid', fail on FINAL failure. This flips
    // the order to paid as soon as the buyer returns (not only when the IPN
    // lands), and is safe because applyCapture is idempotent. A 'pending' result
    // (status 2/3) leaves the payment INITIATED so the later final callback can
    // still capture — failing it here would be terminal and strand a paid order.
    if (verified.ok && verified.invoiceNo) {
      if (verified.outcome === 'paid') {
        await this.payments.applyCapture({
          provider: 'NINEPAY',
          providerRef: verified.invoiceNo,
          paidAmountVnd: verified.amountVnd,
          currency: verified.currency || undefined,
          // Store only the validated fields, not the raw checksum-bearing query.
          payload: {
            source: 'return',
            invoiceNo: verified.invoiceNo,
            outcome: verified.outcome,
            amountVnd: verified.amountVnd,
          },
        });
      } else if (verified.outcome === 'failed') {
        await this.payments.applyFailure({
          provider: 'NINEPAY',
          providerRef: verified.invoiceNo,
          payload: { source: 'return', invoiceNo: verified.invoiceNo, outcome: verified.outcome },
        });
      }
    }
    const status = !verified.ok
      ? 'failed'
      : verified.outcome === 'paid'
        ? 'success'
        : verified.outcome === 'failed'
          ? 'failed'
          : 'pending';
    const orderId =
      verified.ok && verified.invoiceNo
        ? await this.payments.findOrderIdByRef('NINEPAY', verified.invoiceNo)
        : null;
    const orderParam = orderId ? `&order_id=${orderId}` : '';
    res.redirect(`${customerBase}/payments/return/ninepay?status=${status}${orderParam}`);
  }

  /**
   * Authoritative server-to-server IPN from 9Pay. Posted as
   * x-www-form-urlencoded with `result` + `checksum` (+ `version`); we verify
   * the checksum and mark the Payment CAPTURED (status 5) / FAILED (final 6/8/9),
   * or leave it INITIATED for a pending (2/3) result. Always 200 so 9Pay's retry
   * re-delivers the final status instead of treating it as a hard error.
   */
  @SkipThrottle()
  @Public()
  @Post('ninepay/ipn')
  @HttpCode(HttpStatus.OK)
  async ninepayIpn(@Body() body: Record<string, string>): Promise<{ status: string }> {
    const verified = this.ninepay.verifyResult(body);
    if (!verified.ok || !verified.invoiceNo) {
      // Acknowledge so 9Pay doesn't hammer retries; a checksum failure here is
      // logged at ERROR inside verifyResult (it may mean a wrong/rotated
      // NINEPAY_CHECKSUM_KEY — watch for stranded INITIATED payments).
      return { status: 'success' };
    }
    if (verified.outcome === 'paid') {
      await this.payments.applyCapture({
        provider: 'NINEPAY',
        providerRef: verified.invoiceNo,
        paidAmountVnd: verified.amountVnd,
        currency: verified.currency || undefined,
        payload: {
          source: 'ipn',
          invoiceNo: verified.invoiceNo,
          outcome: verified.outcome,
          amountVnd: verified.amountVnd,
        },
      });
    } else if (verified.outcome === 'failed') {
      await this.payments.applyFailure({
        provider: 'NINEPAY',
        providerRef: verified.invoiceNo,
        payload: { source: 'ipn', invoiceNo: verified.invoiceNo, outcome: verified.outcome },
      });
    }
    // 'pending' → no state change; 9Pay re-IPNs the final status on settlement.
    return { status: 'success' };
  }

  /** MoMo authoritative IPN. */
  @SkipThrottle()
  @Public()
  @Post('momo/ipn')
  @HttpCode(HttpStatus.NO_CONTENT)
  async momoIpn(@Body() body: Record<string, unknown>): Promise<void> {
    const verified = this.momo.verifyIpn(body);
    if (!verified.ok || !verified.momoOrderId) return;
    if (verified.resultCode === 0) {
      await this.payments.applyCapture({
        provider: 'MOMO',
        providerRef: verified.momoOrderId,
        paidAmountVnd: verified.amountVnd,
        payload: body,
      });
    } else {
      await this.payments.applyFailure({
        provider: 'MOMO',
        providerRef: verified.momoOrderId,
        payload: body,
      });
    }
  }
}

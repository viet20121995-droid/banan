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

import { MoMoPaymentService } from './providers/momo.service';
import { StripePaymentService } from './providers/stripe.service';
import { VNPayPaymentService } from './providers/vnpay.service';

// Webhook + IPN endpoints are called by upstream providers and can fire in
// bursts — the global throttler would falsely rate-limit them. Skip throttling
// on the whole controller; signature verification is the real gate.
@SkipThrottle()
@ApiTags('payments')
@Controller({ path: 'payments', version: '1' })
export class PaymentsController {
  private readonly logger = new Logger(PaymentsController.name);

  constructor(
    private readonly stripe: StripePaymentService,
    private readonly vnpay: VNPayPaymentService,
    private readonly momo: MoMoPaymentService,
    private readonly config: ConfigService,
  ) {}

  /** Stripe-Signature is required for verification. Stripe sends raw JSON. */
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
    await this.stripe.handleWebhook(req.rawBody, signature);
    return { received: true };
  }

  /**
   * VNPay redirects the user back here after payment. We verify the hash and
   * redirect to the customer app with a status query so the UI can update.
   */
  @Public()
  @Get('vnpay/return')
  async vnpayReturn(
    @Query() query: Record<string, string>,
    @Res() res: Response,
  ) {
    const verified = this.vnpay.verifyCallback(query);
    if (verified.ok && verified.responseCode === '00') {
      await this.vnpay.markCaptured(verified.txnRef!, query as object);
    } else if (verified.ok) {
      await this.vnpay.markFailed(verified.txnRef!, query as object);
    }
    const customerBase =
      this.config.get<string>('CUSTOMER_APP_BASE_URL') ??
      'http://localhost:8081';
    const status = verified.ok && verified.responseCode === '00'
      ? 'success'
      : 'failed';
    res.redirect(
      `${customerBase}/payments/return/vnpay?status=${status}&txnRef=${verified.txnRef ?? ''}`,
    );
  }

  /** Authoritative server-to-server callback from VNPay. */
  @Public()
  @Get('vnpay/ipn')
  async vnpayIpn(
    @Query() query: Record<string, string>,
  ): Promise<{ RspCode: string; Message: string }> {
    const verified = this.vnpay.verifyCallback(query);
    if (!verified.ok) {
      return { RspCode: '97', Message: 'Invalid signature' };
    }
    if (verified.responseCode === '00') {
      await this.vnpay.markCaptured(verified.txnRef!, query as object);
    } else {
      await this.vnpay.markFailed(verified.txnRef!, query as object);
    }
    return { RspCode: '00', Message: 'Confirm Success' };
  }

  /** MoMo authoritative IPN. */
  @Public()
  @Post('momo/ipn')
  @HttpCode(HttpStatus.NO_CONTENT)
  async momoIpn(@Body() body: Record<string, unknown>): Promise<void> {
    const verified = this.momo.verifyIpn(body);
    if (!verified.ok) return;
    if (verified.resultCode === 0) {
      await this.momo.markCaptured(verified.momoOrderId!, body);
    } else {
      await this.momo.markFailed(verified.momoOrderId!, body);
    }
  }
}

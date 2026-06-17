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
import { PayOSPaymentService } from './providers/payos.service';
import { StripePaymentService } from './providers/stripe.service';

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
    private readonly payos: PayOSPaymentService,
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
   * PayOS redirects the customer's browser back here after checkout. This is
   * UX only — we just bounce to the customer app with a status. The DB state
   * is set authoritatively by the webhook below.
   */
  @Public()
  @Get('payos/return')
  payosReturn(@Query() query: Record<string, string>, @Res() res: Response) {
    const customerBase =
      this.config.get<string>('CUSTOMER_APP_BASE_URL') ??
      'http://localhost:8081';
    // PayOS appends e.g. ?code=00&status=PAID&cancel=false&orderCode=...
    const cancelled = query['cancel'] === 'true' || query['status'] === 'CANCELLED';
    const status = !cancelled && query['code'] === '00' ? 'success' : 'failed';
    res.redirect(
      `${customerBase}/payments/return/payos?status=${status}&orderCode=${query['orderCode'] ?? ''}`,
    );
  }

  /** Authoritative server-to-server webhook from PayOS (signed JSON POST). */
  @Public()
  @Post('payos/webhook')
  @HttpCode(HttpStatus.OK)
  async payosWebhook(
    @Body() body: Record<string, unknown>,
  ): Promise<{ success: boolean }> {
    const verified = this.payos.verifyWebhook(body);
    if (!verified.ok || !verified.orderCode) {
      // PayOS sends a test ping with a dummy payload when you register the
      // webhook — acknowledge it so the dashboard accepts the URL.
      return { success: true };
    }
    if (verified.paid) {
      await this.payos.markCaptured(verified.orderCode, body);
    } else {
      await this.payos.markFailed(verified.orderCode, body);
    }
    return { success: true };
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

import { HttpException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'node:crypto';

import { PrismaService } from '../../prisma/prisma.service';

/**
 * PayOS (payos.vn) integration — replaces the previous VNPay flow.
 *
 * Flow: POST a create-payment-link request signed with HMAC-SHA256 over the
 * sorted `amount|cancelUrl|description|orderCode|returnUrl` string, receive a
 * `checkoutUrl`, and redirect the customer there. PayOS then POSTs a signed
 * webhook back to us; we verify the signature and mark the Payment
 * CAPTURED / FAILED. The browser return URL is for UX only — the webhook is
 * authoritative.
 *
 * Configure: PAYOS_CLIENT_ID, PAYOS_API_KEY, PAYOS_CHECKSUM_KEY (+ optional
 * PAYOS_ENDPOINT, PAYOS_RETURN_URL, PAYOS_CANCEL_URL). Without these the
 * service returns a config error and customers fall back to cash on delivery.
 * Register the webhook URL `<API>/api/v1/payments/payos/webhook` in the PayOS
 * dashboard once keys are live.
 */
@Injectable()
export class PayOSPaymentService {
  private readonly logger = new Logger(PayOSPaymentService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  get enabled(): boolean {
    return (
      !!this.config.get<string>('PAYOS_CLIENT_ID') &&
      !!this.config.get<string>('PAYOS_API_KEY') &&
      !!this.config.get<string>('PAYOS_CHECKSUM_KEY')
    );
  }

  private get checksumKey(): string {
    return this.config.get<string>('PAYOS_CHECKSUM_KEY')!;
  }

  async initiate(args: {
    orderId: string;
    orderCode: string;
    amount: string;
    currency: string;
  }): Promise<
    { paymentId: string; redirectUrl: string } | { configurationError: string }
  > {
    if (!this.enabled) {
      return {
        configurationError:
          'PayOS chưa được cấu hình. Thêm PAYOS_CLIENT_ID / PAYOS_API_KEY / PAYOS_CHECKSUM_KEY vào backend/.env.',
      };
    }
    const clientId = this.config.get<string>('PAYOS_CLIENT_ID')!;
    const apiKey = this.config.get<string>('PAYOS_API_KEY')!;
    const endpoint =
      this.config.get<string>('PAYOS_ENDPOINT') ??
      'https://api-merchant.payos.vn/v2/payment-requests';
    const customerBase =
      this.config.get<string>('CUSTOMER_APP_BASE_URL') ??
      'http://localhost:8081';
    const returnUrl =
      this.config.get<string>('PAYOS_RETURN_URL') ??
      `${customerBase}/payments/return/payos`;
    const cancelUrl =
      this.config.get<string>('PAYOS_CANCEL_URL') ?? returnUrl;

    // PayOS requires a NUMERIC, per-merchant-unique orderCode. We derive one
    // from the timestamp and keep the mapping to our order via providerRef so
    // the webhook can locate the Payment row.
    const orderCode = Date.now();
    const amount = Math.round(Number(args.amount)); // PayOS amount is plain VND
    const description = `Banan ${args.orderCode}`.slice(0, 25);

    // Signature input: keys in alphabetical order, joined as key=value&...
    const signatureInput =
      `amount=${amount}` +
      `&cancelUrl=${cancelUrl}` +
      `&description=${description}` +
      `&orderCode=${orderCode}` +
      `&returnUrl=${returnUrl}`;
    const signature = createHmac('sha256', this.checksumKey)
      .update(signatureInput)
      .digest('hex');

    const body = {
      orderCode,
      amount,
      description,
      cancelUrl,
      returnUrl,
      signature,
    };

    const res = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-client-id': clientId,
        'x-api-key': apiKey,
      },
      body: JSON.stringify(body),
    });
    const json = (await res.json()) as {
      code?: string;
      desc?: string;
      data?: { checkoutUrl?: string; paymentLinkId?: string } & Record<string, unknown>;
    };
    if (!res.ok || json.code !== '00' || !json.data?.checkoutUrl) {
      this.logger.error(`PayOS create failed: ${JSON.stringify(json)}`);
      throw new HttpException(
        { code: 'PAYOS_CREATE_FAILED', message: json.desc ?? 'PayOS error' },
        500,
      );
    }

    const payment = await this.prisma.payment.create({
      data: {
        orderId: args.orderId,
        provider: 'PAYOS',
        providerRef: String(orderCode),
        amount: args.amount,
        currency: args.currency,
        status: 'INITIATED',
        rawPayload: json.data as object,
      },
    });

    return { paymentId: payment.id, redirectUrl: json.data.checkoutUrl };
  }

  /**
   * Verifies PayOS's signed webhook. The signature is HMAC-SHA256 over the
   * `data` object's fields sorted alphabetically and joined as key=value&...
   * Returns the orderCode (our providerRef) and whether the payment succeeded.
   */
  verifyWebhook(body: {
    code?: string;
    success?: boolean;
    data?: Record<string, unknown>;
    signature?: string;
  }): { ok: boolean; orderCode?: string; paid?: boolean } {
    if (!this.enabled) return { ok: false };
    const data = body?.data;
    const provided = body?.signature;
    if (!data || !provided) return { ok: false };

    const sortedKeys = Object.keys(data).sort();
    const signData = sortedKeys
      .map((k) => {
        const v = data[k];
        const val = v === null || v === undefined ? '' : String(v);
        return `${k}=${val}`;
      })
      .join('&');
    const expected = createHmac('sha256', this.checksumKey)
      .update(signData)
      .digest('hex');
    if (expected !== provided) {
      this.logger.warn('PayOS webhook signature mismatch');
      return { ok: false };
    }
    return {
      ok: true,
      orderCode: String(data['orderCode'] ?? ''),
      // PayOS marks a paid transaction with data.code === '00'.
      paid: body.code === '00' && String(data['code'] ?? '') === '00',
    };
  }

  async markCaptured(orderCode: string, payload: object): Promise<void> {
    await this.prisma.payment.updateMany({
      where: { provider: 'PAYOS', providerRef: orderCode },
      data: { status: 'CAPTURED', rawPayload: payload },
    });
  }

  async markFailed(orderCode: string, payload: object): Promise<void> {
    await this.prisma.payment.updateMany({
      where: { provider: 'PAYOS', providerRef: orderCode },
      data: { status: 'FAILED', rawPayload: payload },
    });
  }

  /**
   * PayOS does not offer an automatic refund API — refunds are handled by the
   * merchant via bank transfer and reconciled manually. Returns
   * `{ completed: false }` so the Refund stays visible for manual processing.
   */
  // eslint-disable-next-line @typescript-eslint/require-await
  async refund(): Promise<{ completed: boolean; providerRef?: string }> {
    if (!this.enabled) {
      this.logger.warn('PayOS refund requested without configuration');
    }
    return { completed: false };
  }
}

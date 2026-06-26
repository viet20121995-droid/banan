import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, createHmac } from 'node:crypto';

import { PrismaService } from '../../prisma/prisma.service';

/**
 * 9Pay (9pay.vn) Payment Gateway integration — replaces the previous PayOS flow.
 * Docs: https://developers.9pay.vn
 *
 * Create flow (Redirect model, server-to-server):
 *   1. Build the canonicalized param string
 *      `merchantKey=…&invoice_no=…&amount=…&description=…&return_url=…`
 *      (exact documented order, raw values).
 *   2. baseEncode = base64(canonicalized).
 *   3. signature = base64(HMAC-SHA256("POST\n{createUrl}\n{time}\n{canonicalized}",
 *      SECRET key)).
 *   4. POST baseEncode to `{endpoint}/payments/create` with headers
 *      `Authorization: Signature Algorithm=HS256, Credential={merchantKey},
 *      SignedHeaders=, Signature={signature}` and `Date: {time}`.
 *   5. 9Pay returns the hosted-checkout URL; we redirect the customer there.
 *
 * 9Pay then POSTs a server-to-server IPN (x-www-form-urlencoded: `result` +
 * `checksum` + `version`). We verify `checksum == UPPER(sha256(result +
 * CHECKSUM key))`, decode `result` (base64 JSON), and a transaction is PAID when
 * `status === 5` (or `error_code === '000'`); 6/8/9 = failed/cancelled/rejected.
 * The browser return URL is UX-only — the IPN is authoritative.
 *
 * Configure: NINEPAY_MERCHANT_KEY, NINEPAY_SECRET_KEY, NINEPAY_CHECKSUM_KEY
 * (+ optional NINEPAY_ENDPOINT [default SANDBOX], NINEPAY_RETURN_URL). Register
 * the IPN URL `<API>/api/v1/payments/ninepay/ipn` in the 9Pay merchant
 * dashboard. Without the keys the service returns a config error and customers
 * fall back to cash on delivery.
 */
@Injectable()
export class NinePayPaymentService {
  private readonly logger = new Logger(NinePayPaymentService.name);

  // 9Pay success markers in the decoded IPN/return `result`.
  private static readonly STATUS_SUCCESS = 5;
  private static readonly ERROR_CODE_SUCCESS = '000';

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  get enabled(): boolean {
    return (
      !!this.config.get<string>('NINEPAY_MERCHANT_KEY') &&
      !!this.config.get<string>('NINEPAY_SECRET_KEY') &&
      !!this.config.get<string>('NINEPAY_CHECKSUM_KEY')
    );
  }

  /** Gateway base — SANDBOX by default; set to https://payment.9pay.vn for prod. */
  private get baseUrl(): string {
    return this.config.get<string>('NINEPAY_ENDPOINT') ?? 'https://sand-payment.9pay.vn';
  }

  private get checksumKey(): string {
    return this.config.get<string>('NINEPAY_CHECKSUM_KEY')!;
  }

  async initiate(args: {
    orderId: string;
    orderCode: string;
    amount: string;
    currency: string;
  }): Promise<{ paymentId: string; redirectUrl: string } | { configurationError: string }> {
    if (!this.enabled) {
      return {
        configurationError:
          '9Pay chưa được cấu hình. Thêm NINEPAY_MERCHANT_KEY / NINEPAY_SECRET_KEY / NINEPAY_CHECKSUM_KEY vào backend/.env.',
      };
    }
    const merchantKey = this.config.get<string>('NINEPAY_MERCHANT_KEY')!;
    const secretKey = this.config.get<string>('NINEPAY_SECRET_KEY')!;
    const createUrl = `${this.baseUrl}/payments/create`;
    const returnUrl =
      this.config.get<string>('NINEPAY_RETURN_URL') ??
      'http://localhost:3000/api/v1/payments/ninepay/return';

    // 9Pay needs an invoice_no unique per merchant. A Postgres sequence makes it
    // collision-proof (vs timestamp codes that clash in the same millisecond and
    // would trip the Payment.[provider, providerRef] unique index). providerRef
    // = invoice_no, so the IPN can locate the Payment row.
    const seq = await this.prisma.$queryRaw<Array<{ invoiceNo: bigint }>>`
      SELECT nextval('ninepay_invoice_seq') AS "invoiceNo"
    `;
    const invoiceNo = String(seq[0].invoiceNo);
    const amount = Math.round(Number(args.amount)); // 9Pay amount is plain VND
    // ASCII description (<=255) — avoids any signature byte-encoding surprises.
    const description = `Thanh toan don ${args.orderCode}`.slice(0, 255);
    const time = Math.floor(Date.now() / 1000); // 10-digit unix; must match Date header

    // Canonicalized resources — EXACT documented field order, raw (un-encoded)
    // values. This `key=value&…` form is used ONLY to compute the signature
    // (developers.9pay.vn).
    const canonical =
      `merchantKey=${merchantKey}` +
      `&invoice_no=${invoiceNo}` +
      `&amount=${amount}` +
      `&description=${description}` +
      `&return_url=${returnUrl}`;
    // baseEncode (the actual data payload 9Pay decodes) is base64 of the JSON
    // object — NOT the canonical string. It must include EVERY required param,
    // incl. `time` (a required field per 9Pay's doc); omitting it returns
    // "Request error - Wrong data". The canonical above (sans time) is only for
    // the signature, where time is the separate 3rd line.
    const baseEncode = Buffer.from(
      JSON.stringify({
        merchantKey,
        invoice_no: invoiceNo,
        amount,
        description,
        return_url: returnUrl,
        time,
      }),
      'utf8',
    ).toString('base64');

    // 9Pay Payment Gateway uses the REDIRECT model: the buyer's browser is sent
    // (GET) to the hosted checkout at `{base}/portal` with `baseEncode` +
    // `signature` + `time` in the query string. (`/payments/create` 404s — that
    // is only the canonical endpoint used for SIGNING; the actual landing page
    // is `/portal`, confirmed to exist (401 without valid params).) `time` rides
    // as a query param because a browser redirect has no `Date` header.
    // Signature per developers.9pay.vn:
    //   base64(HMAC-SHA256("POST\n{createUrl}\n{time}\n{canonical}", secret))
    // where "POST" is the canonical method token and the URI is the create URL.
    const stringToSign = `POST\n${createUrl}\n${time}\n${canonical}`;
    const signature = createHmac('sha256', secretKey)
      .update(stringToSign, 'utf8')
      .digest('base64');
    const portalUrl = `${this.baseUrl}/portal`;
    const redirectUrl =
      `${portalUrl}?baseEncode=${encodeURIComponent(baseEncode)}` +
      `&signature=${encodeURIComponent(signature)}` +
      `&time=${time}`;

    const payment = await this.prisma.payment.create({
      data: {
        orderId: args.orderId,
        provider: 'NINEPAY',
        providerRef: invoiceNo,
        amount: args.amount,
        currency: args.currency,
        status: 'INITIATED',
        rawPayload: { invoiceNo, createUrl, time },
      },
    });

    return { paymentId: payment.id, redirectUrl };
  }

  /**
   * Verifies a 9Pay `result`+`checksum` payload (used by BOTH the server IPN and
   * the browser return). The checksum is `UPPER(sha256(result + CHECKSUM key))`;
   * `result` base64-decodes to the transaction JSON. Returns the invoice_no
   * (our providerRef) and whether the payment succeeded.
   */
  verifyResult(body: { result?: string; checksum?: string }): {
    ok: boolean;
    invoiceNo?: string;
    paid?: boolean;
    amountVnd?: number;
  } {
    if (!this.enabled) return { ok: false };
    const result = body?.result;
    const checksum = body?.checksum;
    if (!result || !checksum) return { ok: false };

    const expected = createHash('sha256')
      .update(result + this.checksumKey)
      .digest('hex')
      .toUpperCase();
    if (expected !== String(checksum).toUpperCase()) {
      this.logger.warn('9Pay checksum mismatch');
      return { ok: false };
    }

    let data: Record<string, unknown>;
    try {
      data = JSON.parse(Buffer.from(result, 'base64').toString('utf8')) as Record<string, unknown>;
    } catch {
      this.logger.warn('9Pay result is not valid base64 JSON');
      return { ok: false };
    }

    const status = Number(data['status']);
    const errorCode = String(data['error_code'] ?? data['errorCode'] ?? '');
    const paid =
      status === NinePayPaymentService.STATUS_SUCCESS ||
      errorCode === NinePayPaymentService.ERROR_CODE_SUCCESS;

    return {
      ok: true,
      invoiceNo: String(data['invoice_no'] ?? data['invoiceNo'] ?? ''),
      paid,
      amountVnd: Number(data['amount'] ?? 0),
    };
  }

  /**
   * 9Pay exposes a refund API (POST /v2/refunds/create), but it requires a
   * signed server call that we have not yet verified against the merchant
   * account. Until then refunds are handled by staff via the 9Pay dashboard /
   * bank transfer and reconciled manually — return `{ completed: false }` so the
   * Refund stays visible for manual processing (same posture PayOS had).
   */
  // eslint-disable-next-line @typescript-eslint/require-await
  async refund(): Promise<{ completed: boolean; providerRef?: string }> {
    if (!this.enabled) {
      this.logger.warn('9Pay refund requested without configuration');
    }
    return { completed: false };
  }
}

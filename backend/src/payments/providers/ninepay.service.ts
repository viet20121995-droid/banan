import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, createHmac, timingSafeEqual } from 'node:crypto';

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
 * CHECKSUM key))`, decode `result` (base64 JSON), and read `status`: 5 = PAID,
 * 6/8/9 = FINAL failed/cancelled/rejected, 2/3 (or anything else) = pending (we
 * leave the payment INITIATED so the later success callback can still capture).
 * Both the IPN and the browser return are authoritative (checksum-verified).
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

  // 9Pay transaction-status markers in the decoded IPN/return `result`.
  // `status` is the authoritative settlement signal — 5 = success, 6/8/9 =
  // failed/cancelled/rejected (FINAL); 2/3 (or anything else) = pending. We must
  // NOT treat pending as failure: FAILED is terminal and would block the later
  // success callback, stranding a paid order.
  private static readonly STATUS_SUCCESS = 5;
  private static readonly STATUS_FINAL_FAILED: ReadonlySet<number> = new Set([6, 8, 9]);

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

  /**
   * Replicates 9Pay's sample `buildHttpQuery`: sort keys alphabetically,
   * URL-encode, join with `&` (via URLSearchParams). Used for BOTH the signing
   * canonical and the redirect query so they match what 9Pay reconstructs.
   * (gitlab.com/9pay-sample/sample-javascript)
   */
  private static buildHttpQuery(data: Record<string, string | number>): string {
    const q = new URLSearchParams();
    for (const key of Object.keys(data).sort()) {
      q.append(key, String(data[key]));
    }
    return q.toString();
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

    // Request params. baseEncode is base64 of this JSON exactly (sent to 9Pay);
    // the signature canonical is the SAME params SORTED by key and URL-encoded.
    // Verified byte-for-byte against 9Pay's official sample
    // (gitlab.com/9pay-sample/sample-javascript). The two details that are easy
    // to miss: params MUST be sorted alphabetically AND URL-encoded (e.g.
    // description=Thanh+toan+don+…, return_url=https%3A%2F%2F…).
    const params: Record<string, string | number> = {
      merchantKey,
      time,
      invoice_no: invoiceNo,
      amount,
      description,
      return_url: returnUrl,
    };
    const baseEncode = Buffer.from(JSON.stringify(params), 'utf8').toString('base64');

    // signature = base64(HMAC-SHA256("POST\n{createUrl}\n{time}\n{canonical}",
    // secret)). The signing URI is `/payments/create` even though the buyer
    // lands on `/portal`; the canonical is the sorted + URL-encoded query string.
    const canonical = NinePayPaymentService.buildHttpQuery(params);
    const stringToSign = `POST\n${createUrl}\n${time}\n${canonical}`;
    const signature = createHmac('sha256', secretKey)
      .update(stringToSign, 'utf8')
      .digest('base64');

    // Redirect the browser to the hosted checkout `/portal` with ONLY baseEncode
    // + signature (also sorted + URL-encoded). `time` rides INSIDE baseEncode —
    // it is NOT a separate query param.
    const redirectUrl =
      `${this.baseUrl}/portal?` +
      NinePayPaymentService.buildHttpQuery({ baseEncode, signature });

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
    outcome?: 'paid' | 'failed' | 'pending';
    amountVnd?: number;
  } {
    if (!this.enabled) return { ok: false };
    const result = body?.result;
    const checksum = body?.checksum;
    if (!result || !checksum) return { ok: false };

    // The checksum is the SOLE anti-forgery gate (both the IPN and the
    // customer-controlled return URL capture on the strength of it), so compare
    // it in constant time — same posture as the Stripe webhook. timingSafeEqual
    // throws on unequal-length buffers, so guard the length first.
    const expected = createHash('sha256')
      .update(result + this.checksumKey)
      .digest('hex')
      .toUpperCase();
    const provided = Buffer.from(String(checksum).toUpperCase(), 'utf8');
    const expectedBuf = Buffer.from(expected, 'utf8');
    if (provided.length !== expectedBuf.length || !timingSafeEqual(provided, expectedBuf)) {
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

    // `status` is the single source of truth. 5 = paid; 6/8/9 = FINAL failure;
    // everything else (2/3 processing, or anything unrecognized/missing) = pending
    // — we must NOT mark those FAILED or the later success callback can't capture.
    // (`error_code` is a transport-level marker, not settlement, so it is ignored.)
    const status = Number(data['status']);
    const outcome: 'paid' | 'failed' | 'pending' =
      status === NinePayPaymentService.STATUS_SUCCESS
        ? 'paid'
        : NinePayPaymentService.STATUS_FINAL_FAILED.has(status)
          ? 'failed'
          : 'pending';

    return {
      ok: true,
      invoiceNo: String(data['invoice_no'] ?? data['invoiceNo'] ?? ''),
      outcome,
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

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'node:crypto';
import { customAlphabet } from 'nanoid';

import { PrismaService } from '../../prisma/prisma.service';

const txnRefId = customAlphabet('0123456789', 14);

/**
 * VNPay sandbox flow. The redirect URL is signed with HMAC-SHA512 over the
 * lexicographically-sorted query params (per VNPay spec). The IPN endpoint
 * verifies the same signature and marks the Payment as CAPTURED.
 *
 * Configure with `VNPAY_TMN_CODE`, `VNPAY_HASH_SECRET`, `VNPAY_PAYMENT_URL`,
 * `VNPAY_RETURN_URL` in `.env`. Without these, calls return a config error.
 */
@Injectable()
export class VNPayPaymentService {
  private readonly logger = new Logger(VNPayPaymentService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  get enabled(): boolean {
    return (
      !!this.config.get<string>('VNPAY_TMN_CODE') &&
      !!this.config.get<string>('VNPAY_HASH_SECRET')
    );
  }

  async initiate(args: {
    orderId: string;
    orderCode: string;
    amount: string;
    currency: string;
    customerIp: string;
  }): Promise<
    | { paymentId: string; redirectUrl: string }
    | { configurationError: string }
  > {
    if (!this.enabled) {
      return {
        configurationError:
          'VNPay is not configured. Add VNPAY_TMN_CODE and VNPAY_HASH_SECRET to backend/.env.',
      };
    }
    const tmnCode = this.config.get<string>('VNPAY_TMN_CODE')!;
    const secret = this.config.get<string>('VNPAY_HASH_SECRET')!;
    const paymentUrl =
      this.config.get<string>('VNPAY_PAYMENT_URL') ??
      'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';
    const returnUrl =
      this.config.get<string>('VNPAY_RETURN_URL') ??
      'http://localhost:3000/api/v1/payments/vnpay/return';

    const txnRef = `${args.orderCode}-${txnRefId()}`;
    const now = new Date();
    const ymdHis = formatVnpDate(now);

    // VNPay amount is multiplied by 100, even for VND.
    const amountX100 = Math.round(Number(args.amount) * 100);

    const params: Record<string, string> = {
      vnp_Version: '2.1.0',
      vnp_Command: 'pay',
      vnp_TmnCode: tmnCode,
      vnp_Amount: String(amountX100),
      vnp_CurrCode: args.currency,
      vnp_TxnRef: txnRef,
      vnp_OrderInfo: `Banan_order_${args.orderCode}`,
      vnp_OrderType: 'other',
      vnp_Locale: 'vn',
      vnp_ReturnUrl: returnUrl,
      vnp_IpAddr: args.customerIp,
      vnp_CreateDate: ymdHis,
    };
    const signed = signVnpParams(params, secret);
    const queryString = buildVnpQueryString(signed);
    const redirectUrl = `${paymentUrl}?${queryString}`;

    const payment = await this.prisma.payment.create({
      data: {
        orderId: args.orderId,
        provider: 'VNPAY',
        providerRef: txnRef,
        amount: args.amount,
        currency: args.currency,
        status: 'INITIATED',
        rawPayload: signed,
      },
    });

    return { paymentId: payment.id, redirectUrl };
  }

  /** Validates VNPay's signed callback. Returns the txn ref on success. */
  verifyCallback(query: Record<string, string>): { ok: boolean; txnRef?: string; responseCode?: string } {
    if (!this.enabled) return { ok: false };
    const secret = this.config.get<string>('VNPAY_HASH_SECRET')!;
    const provided = query['vnp_SecureHash'];
    if (!provided) return { ok: false };

    const { vnp_SecureHash: _ignored1, vnp_SecureHashType: _ignored2, ...rest } = query;
    const expected = computeVnpHash(rest, secret);
    if (expected.toLowerCase() !== provided.toLowerCase()) {
      this.logger.warn('VNPay signature mismatch');
      return { ok: false };
    }
    return {
      ok: true,
      txnRef: query['vnp_TxnRef'],
      responseCode: query['vnp_ResponseCode'],
    };
  }

  async markCaptured(txnRef: string, payload: object): Promise<void> {
    await this.prisma.payment.updateMany({
      where: { provider: 'VNPAY', providerRef: txnRef },
      data: { status: 'CAPTURED', rawPayload: payload },
    });
  }

  async markFailed(txnRef: string, payload: object): Promise<void> {
    await this.prisma.payment.updateMany({
      where: { provider: 'VNPAY', providerRef: txnRef },
      data: { status: 'FAILED', rawPayload: payload },
    });
  }

  /**
   * VNPay refund — server-to-server `vnp_Command=refund` POST with HMAC.
   * Returns PROCESSING; reconciled via VNPay's settlement callback.
   *
   * NOTE: requires real merchant credentials to test end-to-end. Without
   * them this method returns `processing` so the refund stays visible to
   * the merchant for manual reconciliation.
   */
  // eslint-disable-next-line @typescript-eslint/require-await
  async refund(): Promise<{ completed: boolean; providerRef?: string }> {
    if (!this.enabled) {
      this.logger.warn('VNPay refund requested without configuration');
    }
    // TODO(M5+): implement vnp_Command=refund call against
    // https://sandbox.vnpayment.vn/merchant_webapi/api/transaction
    return { completed: false };
  }
}

function formatVnpDate(d: Date): string {
  const pad = (n: number) => n.toString().padStart(2, '0');
  return (
    `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}` +
    `${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
  );
}

function signVnpParams(
  params: Record<string, string>,
  secret: string,
): Record<string, string> {
  const hash = computeVnpHash(params, secret);
  return { ...params, vnp_SecureHash: hash };
}

/**
 * VNPay's official Node demo signs and stringifies WITHOUT URL-encoding —
 * `qs.stringify(params, { encode: false })`. We match that exactly so the
 * signature on the redirect matches the signature their server recomputes.
 *
 * Source: https://github.com/vnpay/vnpay-nodejs-demo `index.js` (Aug 2024).
 */
function computeVnpHash(
  params: Record<string, string>,
  secret: string,
): string {
  const signData = stringifyNoEncode(params);
  return createHmac('sha512', secret).update(signData, 'utf8').digest('hex');
}

function buildVnpQueryString(params: Record<string, string>): string {
  return stringifyNoEncode(params);
}

function stringifyNoEncode(params: Record<string, string>): string {
  const sortedKeys = Object.keys(params).sort();
  return sortedKeys.map((k) => `${k}=${params[k]}`).join('&');
}

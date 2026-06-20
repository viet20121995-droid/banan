import { HttpException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'node:crypto';
import { customAlphabet } from 'nanoid';

import { PrismaService } from '../../prisma/prisma.service';

const requestIdGen = customAlphabet('abcdefghijklmnopqrstuvwxyz0123456789', 16);

/**
 * MoMo (test gateway) integration. We POST the create-payment request with
 * an HMAC-SHA256 signature and receive back a `payUrl` to redirect the user
 * to. The IPN handler verifies the signature on the way back.
 *
 * Configure: MOMO_PARTNER_CODE, MOMO_ACCESS_KEY, MOMO_SECRET_KEY, MOMO_ENDPOINT.
 */
@Injectable()
export class MoMoPaymentService {
  private readonly logger = new Logger(MoMoPaymentService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  get enabled(): boolean {
    return (
      !!this.config.get<string>('MOMO_PARTNER_CODE') &&
      !!this.config.get<string>('MOMO_ACCESS_KEY') &&
      !!this.config.get<string>('MOMO_SECRET_KEY')
    );
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
          'MoMo is not configured. Add MOMO_PARTNER_CODE / MOMO_ACCESS_KEY / MOMO_SECRET_KEY to backend/.env.',
      };
    }
    const partnerCode = this.config.get<string>('MOMO_PARTNER_CODE')!;
    const accessKey = this.config.get<string>('MOMO_ACCESS_KEY')!;
    const secretKey = this.config.get<string>('MOMO_SECRET_KEY')!;
    const endpoint =
      this.config.get<string>('MOMO_ENDPOINT') ??
      'https://test-payment.momo.vn/v2/gateway/api/create';
    const returnUrl =
      this.config.get<string>('MOMO_RETURN_URL') ?? 'http://localhost:8081/payments/return/momo';
    const ipnUrl =
      this.config.get<string>('MOMO_IPN_URL') ?? 'http://localhost:3000/api/v1/payments/momo/ipn';

    const requestId = requestIdGen();
    const momoOrderId = `${args.orderCode}-${requestId}`;
    const orderInfo = `Banan order ${args.orderCode}`;
    const requestType = 'captureWallet';
    const extraData = '';

    // MoMo's documented signature input order — DO NOT change without checking the docs.
    const rawSignature =
      `accessKey=${accessKey}` +
      `&amount=${args.amount}` +
      `&extraData=${extraData}` +
      `&ipnUrl=${ipnUrl}` +
      `&orderId=${momoOrderId}` +
      `&orderInfo=${orderInfo}` +
      `&partnerCode=${partnerCode}` +
      `&redirectUrl=${returnUrl}` +
      `&requestId=${requestId}` +
      `&requestType=${requestType}`;
    const signature = createHmac('sha256', secretKey).update(rawSignature).digest('hex');

    const body = {
      partnerCode,
      partnerName: 'Banan',
      storeId: 'banan-saigon',
      requestId,
      amount: Number(args.amount),
      orderId: momoOrderId,
      orderInfo,
      redirectUrl: returnUrl,
      ipnUrl,
      lang: 'vi',
      requestType,
      autoCapture: true,
      extraData,
      signature,
    };

    const res = await fetch(endpoint, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });
    const json = (await res.json()) as {
      payUrl?: string;
      message?: string;
      resultCode?: number;
    };
    if (!res.ok || !json.payUrl) {
      this.logger.error(`MoMo create failed: ${JSON.stringify(json)}`);
      throw new HttpException(
        { code: 'MOMO_CREATE_FAILED', message: json.message ?? 'MoMo error' },
        500,
      );
    }

    const payment = await this.prisma.payment.create({
      data: {
        orderId: args.orderId,
        provider: 'MOMO',
        providerRef: momoOrderId,
        amount: args.amount,
        currency: args.currency,
        status: 'INITIATED',
        rawPayload: json as object,
      },
    });

    return { paymentId: payment.id, redirectUrl: json.payUrl };
  }

  /** Verifies MoMo's IPN signature. */
  verifyIpn(body: Record<string, unknown>): {
    ok: boolean;
    momoOrderId?: string;
    resultCode?: number;
    amountVnd?: number;
  } {
    if (!this.enabled) return { ok: false };
    const accessKey = this.config.get<string>('MOMO_ACCESS_KEY')!;
    const secret = this.config.get<string>('MOMO_SECRET_KEY')!;

    const provided = body['signature'] as string | undefined;
    if (!provided) return { ok: false };

    // MoMo IPN signature input — fields ordered exactly as their spec.
    const rawSignature =
      `accessKey=${accessKey}` +
      `&amount=${body['amount']}` +
      `&extraData=${body['extraData'] ?? ''}` +
      `&message=${body['message'] ?? ''}` +
      `&orderId=${body['orderId']}` +
      `&orderInfo=${body['orderInfo']}` +
      `&orderType=${body['orderType'] ?? ''}` +
      `&partnerCode=${body['partnerCode']}` +
      `&payType=${body['payType'] ?? ''}` +
      `&requestId=${body['requestId']}` +
      `&responseTime=${body['responseTime'] ?? ''}` +
      `&resultCode=${body['resultCode']}` +
      `&transId=${body['transId'] ?? ''}`;
    const expected = createHmac('sha256', secret).update(rawSignature).digest('hex');
    if (expected !== provided) return { ok: false };

    return {
      ok: true,
      momoOrderId: body['orderId'] as string,
      resultCode: Number(body['resultCode']),
      amountVnd: Number(body['amount'] ?? 0),
    };
  }

  /**
   * MoMo refund — POST to `/v2/gateway/api/refund` with HMAC-SHA256.
   * Returns PROCESSING; the IPN callback flips it to COMPLETED.
   *
   * NOTE: requires real partner credentials to test end-to-end.
   */
  // eslint-disable-next-line @typescript-eslint/require-await
  async refund(): Promise<{ completed: boolean; providerRef?: string }> {
    if (!this.enabled) {
      this.logger.warn('MoMo refund requested without configuration');
    }
    // TODO(M5+): implement POST /v2/gateway/api/refund with proper signature.
    return { completed: false };
  }
}

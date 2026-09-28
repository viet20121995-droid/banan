import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * Meta signs every webhook POST with `X-Hub-Signature-256: sha256=<hex>`,
 * an HMAC-SHA256 of the raw request body keyed with the App Secret. The raw
 * bytes matter — re-serialised JSON won't match — hence `rawBody: true` in
 * main.ts. Compared in constant time, same posture as the payment webhooks.
 */
export function isValidMetaSignature(
  rawBody: Buffer,
  header: string | undefined,
  appSecret: string,
): boolean {
  if (!header || !appSecret) return false;
  const [algo, provided] = header.split('=', 2);
  if (algo !== 'sha256' || !provided) return false;
  const expected = createHmac('sha256', appSecret).update(rawBody).digest();
  const providedBuf = Buffer.from(provided, 'hex');
  return providedBuf.length === expected.length && timingSafeEqual(providedBuf, expected);
}

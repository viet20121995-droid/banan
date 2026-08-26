import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

/**
 * Opaque secret-link tokens for Mystery Shopper assignments. 32 random bytes
 * (base64url, 43 chars) — never sequential, never derived from ids. Only the
 * sha256 hash is stored; the raw token exists once in the create/regenerate
 * response and in the link handed to the shopper.
 */
export function generateMsToken(): { raw: string; hash: string } {
  const raw = randomBytes(32).toString('base64url');
  return { raw, hash: hashMsToken(raw) };
}

export function hashMsToken(raw: string): string {
  return createHash('sha256').update(raw, 'utf8').digest('hex');
}

/** Constant-time hash comparison — token lookups must not leak via timing. */
export function msTokenHashEquals(a: string, b: string): boolean {
  const ba = Buffer.from(a, 'hex');
  const bb = Buffer.from(b, 'hex');
  return ba.length === bb.length && timingSafeEqual(ba, bb);
}

import { customAlphabet } from 'nanoid';

/** 6-char alphabetically-ordered suffix — random but readable. */
const tail = customAlphabet('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 6);

/** Generates a human-readable order code like `BAN-2026-7Q3K2X`. */
export function generateOrderCode(now: Date = new Date()): string {
  return `BAN-${now.getUTCFullYear()}-${tail()}`;
}

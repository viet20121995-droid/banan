import { randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, unlinkSync } from 'node:fs';
import { join } from 'node:path';

import { BadRequestException } from '@nestjs/common';

/**
 * PRIVATE file store for internal-ops evidence (QC/MS photos, receipts,
 * training PDFs). Lives OUTSIDE the publicly served `uploads/` directory —
 * nothing here is reachable without an authorised endpoint.
 */
export const PRIVATE_UPLOAD_DIR = 'uploads-private';

const PRIVATE_NAME = /^[a-f0-9]{32}\.(jpg|png|webp|pdf)$/;

const EXT_BY_MIME: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'application/pdf': '.pdf',
};

export const MIME_BY_EXT: Record<string, string> = {
  '.jpg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.pdf': 'application/pdf',
};

export function ensurePrivateDir(): string {
  const dir = join(process.cwd(), PRIVATE_UPLOAD_DIR);
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  return dir;
}

/** Unguessable name from crypto randomness — NOT timestamp+Math.random. */
export function privateFileName(mime: string): string {
  const ext = EXT_BY_MIME[mime];
  if (!ext) {
    throw new BadRequestException({
      code: 'INTERNAL_FILE_TYPE',
      message: 'Định dạng tệp không được hỗ trợ.',
    });
  }
  return `${randomBytes(16).toString('hex')}${ext}`;
}

export function isPrivateFileName(name: string): boolean {
  return PRIVATE_NAME.test(name);
}

export function assertPrivateFileName(name: string, codePrefix: string): void {
  if (!isPrivateFileName(name)) {
    throw new BadRequestException({
      code: `${codePrefix}_BAD_EVIDENCE_NAME`,
      message: 'Ảnh/tệp bằng chứng phải được tải lên qua hệ thống.',
    });
  }
}

/** Best-effort disk removal AFTER the referencing DB row is gone. Never
 *  throws — a leftover file is only hygiene, and the daily orphan sweep
 *  catches anything missed here. */
export function removePrivateFile(name: string): void {
  if (!isPrivateFileName(name)) return;
  try {
    unlinkSync(join(ensurePrivateDir(), name));
  } catch {
    // already gone / locked — the orphan sweep will retry
  }
}

/** Absolute path for a validated private name (no traversal possible —
 *  the name regex admits hex + one known extension only). */
export function privateFilePath(name: string): string {
  if (!isPrivateFileName(name)) {
    throw new BadRequestException({
      code: 'INTERNAL_FILE_NAME',
      message: 'Tên tệp không hợp lệ.',
    });
  }
  return join(ensurePrivateDir(), name);
}

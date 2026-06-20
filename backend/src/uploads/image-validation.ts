import { closeSync, openSync, readSync } from 'node:fs';

/**
 * Upload safety helpers, kept pure + standalone so they can be unit-tested
 * without spinning up HTTP/multer/disk.
 *
 * The two rules together stop a signed-in user from parking executable/HTML
 * content under the API domain:
 *   1. the stored extension comes from the server-detected MIME, never the
 *      client filename;
 *   2. the saved bytes must actually start with an allowed image's magic
 *      bytes — a spoofed `Content-Type: image/png` on an HTML/script payload
 *      is rejected.
 */

export const IMAGE_MIME_EXT: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/avif': '.avif',
};

export const ACCEPTED_IMAGE_MIMES = new Set(Object.keys(IMAGE_MIME_EXT));

/** Extension for an accepted MIME; `.bin` for anything unexpected. */
export function extForMime(mime: string): string {
  return IMAGE_MIME_EXT[mime] ?? '.bin';
}

/** True when the buffer's leading bytes match a supported raster image. */
export function sniffImageBuffer(buf: Buffer): boolean {
  if (buf.length < 12) return false;
  // JPEG: FF D8 FF
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return true;
  // PNG: 89 50 4E 47
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) {
    return true;
  }
  // WEBP: "RIFF"...."WEBP"
  if (buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') {
    return true;
  }
  // AVIF / HEIF family: "....ftyp" + brand avif/avis/mif1/miaf
  if (buf.toString('ascii', 4, 8) === 'ftyp') {
    const brand = buf.toString('ascii', 8, 12);
    if (['avif', 'avis', 'mif1', 'miaf'].includes(brand)) return true;
  }
  return false;
}

/** Reads the first bytes of a saved file and sniffs it. */
export function fileLooksLikeImage(absPath: string): boolean {
  let fd: number | undefined;
  try {
    fd = openSync(absPath, 'r');
    const buf = Buffer.alloc(16);
    const n = readSync(fd, buf, 0, 16, 0);
    return sniffImageBuffer(buf.subarray(0, n));
  } catch {
    return false;
  } finally {
    if (fd !== undefined) closeSync(fd);
  }
}

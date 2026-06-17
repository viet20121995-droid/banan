import {
  BadRequestException,
  Controller,
  Post,
  Req,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { Role } from '@prisma/client';
import type { Request } from 'express';
import { closeSync, openSync, readSync, unlinkSync } from 'node:fs';
import { diskStorage } from 'multer';

import { Roles } from '../auth/decorators/roles.decorator';

// Extension is derived from the (server-detected) MIME — never from the
// client-supplied filename — so an attacker can't keep a `.html`/`.svg`
// extension on a file served under the API domain.
const MIME_EXT: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/avif': '.avif',
};
const ACCEPT = new Set(Object.keys(MIME_EXT));

/** Reads the first bytes of the saved file and confirms it really is one of
 *  the allowed raster image formats (magic-byte sniffing). Defends against a
 *  spoofed Content-Type — the declared MIME is not trusted on its own. */
function looksLikeAllowedImage(absPath: string): boolean {
  let fd: number | undefined;
  try {
    fd = openSync(absPath, 'r');
    const buf = Buffer.alloc(16);
    const n = readSync(fd, buf, 0, 16, 0);
    if (n < 12) return false;
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
  } catch {
    return false;
  } finally {
    if (fd !== undefined) closeSync(fd);
  }
}

@ApiTags('uploads')
@Controller({ path: 'uploads', version: '1' })
export class UploadsController {
  /**
   * Minimal local-disk uploader used in development. Files land under
   * `backend/uploads/` and are served by the Express static handler in
   * `main.ts`. M-later swaps this for an S3 / R2 pre-signed flow without
   * changing the response shape.
   */
  // Customers may upload too (profile avatar). Image-only + 20 MB cap below;
  // a tighter rate limit guards against storage abuse by signed-in users.
  @Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN, Role.CUSTOMER)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post()
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: 'uploads',
        filename: (_req, file, cb) => {
          const stamp = Date.now().toString(36);
          const rand = Math.random().toString(36).slice(2, 8);
          // Extension from the accepted MIME, NOT the client filename.
          const ext = MIME_EXT[file.mimetype] ?? '.bin';
          cb(null, `${stamp}-${rand}${ext}`);
        },
      }),
      // Hard server limit. Modern phone photos easily hit 6-12 MB, and
      // raw exports from cameras can exceed that, so we leave plenty of
      // headroom. The merchant UI still suggests staying under ~8 MB for
      // faster page loads on the customer site, but uploads up to this
      // value are accepted.
      limits: { fileSize: 20 * 1024 * 1024 }, // 20 MB
      fileFilter: (_req, file, cb) => {
        cb(null, ACCEPT.has(file.mimetype));
      },
    }),
  )
  upload(@UploadedFile() file: Express.Multer.File, @Req() req: Request) {
    if (!file) throw new BadRequestException({ code: 'UPLOAD_NO_FILE' });
    // Magic-byte check on the bytes actually written — reject (and delete) a
    // file whose real content isn't an allowed image, regardless of the
    // declared Content-Type.
    if (!looksLikeAllowedImage(file.path)) {
      try {
        unlinkSync(file.path);
      } catch {
        /* best-effort cleanup */
      }
      throw new BadRequestException({
        code: 'UPLOAD_NOT_AN_IMAGE',
        message: 'Tệp tải lên không phải ảnh hợp lệ (JPG/PNG/WebP/AVIF).',
      });
    }
    const baseUrl = `${req.protocol}://${req.get('host')}`;
    return {
      url: `${baseUrl}/uploads/${file.filename}`,
      filename: file.filename,
      size: file.size,
      mimeType: file.mimetype,
    };
  }
}

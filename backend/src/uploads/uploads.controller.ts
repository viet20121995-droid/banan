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
import { unlinkSync } from 'node:fs';
import { diskStorage } from 'multer';

import { Roles } from '../auth/decorators/roles.decorator';

import { ACCEPTED_IMAGE_MIMES, extForMime, fileLooksLikeImage } from './image-validation';

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
          cb(null, `${stamp}-${rand}${extForMime(file.mimetype)}`);
        },
      }),
      // Hard server limit. Modern phone photos easily hit 6-12 MB, and
      // raw exports from cameras can exceed that, so we leave plenty of
      // headroom. The merchant UI still suggests staying under ~8 MB for
      // faster page loads on the customer site, but uploads up to this
      // value are accepted.
      limits: { fileSize: 20 * 1024 * 1024 }, // 20 MB
      fileFilter: (_req, file, cb) => {
        cb(null, ACCEPTED_IMAGE_MIMES.has(file.mimetype));
      },
    }),
  )
  upload(@UploadedFile() file: Express.Multer.File, @Req() req: Request) {
    if (!file) throw new BadRequestException({ code: 'UPLOAD_NO_FILE' });
    // Magic-byte check on the bytes actually written — reject (and delete) a
    // file whose real content isn't an allowed image, regardless of the
    // declared Content-Type.
    if (!fileLooksLikeImage(file.path)) {
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

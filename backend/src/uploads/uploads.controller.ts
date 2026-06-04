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
import { Role } from '@prisma/client';
import type { Request } from 'express';
import { diskStorage } from 'multer';
import { extname } from 'node:path';

import { Roles } from '../auth/decorators/roles.decorator';

const ACCEPT = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/avif']);

@ApiTags('uploads')
@Controller({ path: 'uploads', version: '1' })
export class UploadsController {
  /**
   * Minimal local-disk uploader used in development. Files land under
   * `backend/uploads/` and are served by the Express static handler in
   * `main.ts`. M-later swaps this for an S3 / R2 pre-signed flow without
   * changing the response shape.
   */
  @Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
  @Post()
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: 'uploads',
        filename: (_req, file, cb) => {
          const stamp = Date.now().toString(36);
          const rand = Math.random().toString(36).slice(2, 8);
          cb(null, `${stamp}-${rand}${extname(file.originalname).toLowerCase()}`);
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
    const baseUrl = `${req.protocol}://${req.get('host')}`;
    return {
      url: `${baseUrl}/uploads/${file.filename}`,
      filename: file.filename,
      size: file.size,
      mimeType: file.mimetype,
    };
  }
}

import { closeSync, existsSync, openSync, readSync, unlinkSync } from 'node:fs';
import { extname } from 'node:path';

import {
  BadRequestException,
  Controller,
  Get,
  NotFoundException,
  Param,
  Post,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { Role } from '@prisma/client';
import type { Response } from 'express';
import { diskStorage } from 'multer';

import { Roles } from '../../auth/decorators/roles.decorator';
import { ACCEPTED_IMAGE_MIMES, fileLooksLikeImage } from '../../uploads/image-validation';

import {
  MIME_BY_EXT,
  ensurePrivateDir,
  isPrivateFileName,
  privateFileName,
  privateFilePath,
} from './internal-files.util';

/** Real content check for PDFs — magic bytes, never the extension. */
function fileLooksLikePdf(absPath: string): boolean {
  let fd: number | undefined;
  try {
    fd = openSync(absPath, 'r');
    const buf = Buffer.alloc(5);
    const n = readSync(fd, buf, 0, 5, 0);
    return n === 5 && buf.toString('ascii') === '%PDF-';
  } catch {
    return false;
  } finally {
    if (fd !== undefined) closeSync(fd);
  }
}

/**
 * PRIVATE file store endpoints — ADMIN only. Evidence photos, receipts and
 * training PDFs are NEVER served from the public `/uploads` static mount;
 * they live in `uploads-private/` and stream only through here (or through
 * the token-guarded MS public endpoint).
 */
@ApiBearerAuth()
@ApiTags('internal.files')
@Controller({ path: 'internal/files', version: '1' })
@Roles(Role.ADMIN)
export class InternalFilesController {
  constructor() {
    ensurePrivateDir();
  }

  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (_req, _file, cb) => cb(null, ensurePrivateDir()),
        filename: (_req, file, cb) => cb(null, privateFileName(file.mimetype)),
      }),
      limits: { fileSize: 20 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        cb(null, ACCEPTED_IMAGE_MIMES.has(file.mimetype) && file.mimetype !== 'image/avif');
      },
    }),
  )
  uploadImage(@UploadedFile() file: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException({
        code: 'INTERNAL_FILE_NO_FILE',
        message: 'Chưa chọn ảnh (JPG/PNG/WebP).',
      });
    }
    if (!fileLooksLikeImage(file.path)) {
      this.cleanup(file.path);
      throw new BadRequestException({
        code: 'INTERNAL_FILE_NOT_IMAGE',
        message: 'Tệp tải lên không phải ảnh hợp lệ.',
      });
    }
    return { name: file.filename, size: file.size, mimeType: file.mimetype };
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('upload-pdf')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (_req, _file, cb) => cb(null, ensurePrivateDir()),
        filename: (_req, _file, cb) => cb(null, privateFileName('application/pdf')),
      }),
      limits: { fileSize: 50 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        cb(null, file.mimetype === 'application/pdf');
      },
    }),
  )
  uploadPdf(@UploadedFile() file: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException({
        code: 'INTERNAL_FILE_NO_FILE',
        message: 'Chưa chọn file PDF.',
      });
    }
    if (!fileLooksLikePdf(file.path)) {
      this.cleanup(file.path);
      throw new BadRequestException({
        code: 'INTERNAL_FILE_NOT_PDF',
        message: 'Tệp tải lên không phải PDF hợp lệ.',
      });
    }
    return { name: file.filename, size: file.size, mimeType: 'application/pdf' };
  }

  /** Streams a private file to an ADMIN (Bearer-authenticated fetch — the
   *  apps render the bytes; nothing here is linkable publicly). */
  @Get(':name')
  read(@Param('name') name: string, @Res() res: Response) {
    if (!isPrivateFileName(name)) {
      throw new NotFoundException({
        code: 'INTERNAL_FILE_NOT_FOUND',
        message: 'Không tìm thấy tệp.',
      });
    }
    const path = privateFilePath(name);
    if (!existsSync(path)) {
      throw new NotFoundException({
        code: 'INTERNAL_FILE_NOT_FOUND',
        message: 'Không tìm thấy tệp.',
      });
    }
    res
      .status(200)
      .setHeader('Content-Type', MIME_BY_EXT[extname(name)] ?? 'application/octet-stream')
      .setHeader('Cache-Control', 'private, max-age=3600')
      .sendFile(path);
  }

  private cleanup(path: string): void {
    try {
      unlinkSync(path);
    } catch {
      /* best-effort */
    }
  }
}

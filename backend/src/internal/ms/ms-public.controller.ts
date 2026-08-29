import { existsSync, unlinkSync } from 'node:fs';
import { extname } from 'node:path';

import {
  BadRequestException,
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  NotFoundException,
  Post,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { Response } from 'express';
import { diskStorage } from 'multer';

import { Public } from '../../auth/decorators/public.decorator';
import { ACCEPTED_IMAGE_MIMES, fileLooksLikeImage } from '../../uploads/image-validation';
import {
  MIME_BY_EXT,
  ensurePrivateDir,
  isPrivateFileName,
  privateFileName,
  privateFilePath,
} from '../files/internal-files.util';

import {
  PublicFileDto,
  PublicRemoveEvidenceDto,
  PublicSaveDto,
  PublicTokenDto,
  SelfServiceCreateDto,
} from './dto';
import { MsService } from './ms.service';

/**
 * Public Mystery Shopper endpoints. The shopper has no account — access is
 * the opaque secret token, carried in the POST BODY on every call. Never in
 * the URL: the logging middleware records full request URLs, and a token in
 * a path or query string would land in the logs in cleartext.
 *
 * Evidence goes to the PRIVATE store (`uploads-private/`, crypto-random
 * names) — receipts and inspection photos are never publicly reachable; the
 * shopper reads their own photos back through the token-guarded `file`
 * endpoint below, admins through /internal/files.
 */
@ApiTags('internal.ms.public')
@Controller({ path: 'internal/ms/public', version: '1' })
export class MsPublicController {
  constructor(private readonly ms: MsService) {
    ensurePrivateDir();
  }

  /**
   * Employee self-service link generator — guarded by the shared internal
   * access code, NOT by an account. Tight throttle: this is the only public
   * endpoint that can create rows.
   */
  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('create-assignment')
  @HttpCode(HttpStatus.OK)
  createAssignment(@Body() dto: SelfServiceCreateDto) {
    return this.ms.selfServiceCreate(dto);
  }

  @Public()
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('view')
  @HttpCode(HttpStatus.OK)
  view(@Body() dto: PublicTokenDto) {
    return this.ms.publicView(dto.token);
  }

  @Public()
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('save')
  @HttpCode(HttpStatus.OK)
  save(@Body() dto: PublicSaveDto) {
    return this.ms.publicSave(dto);
  }

  @Public()
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('submit')
  @HttpCode(HttpStatus.OK)
  submit(@Body() dto: PublicTokenDto) {
    return this.ms.publicSubmit(dto.token);
  }

  @Public()
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('remove-evidence')
  @HttpCode(HttpStatus.OK)
  removeEvidence(@Body() dto: PublicRemoveEvidenceDto) {
    return this.ms.publicRemoveEvidence(dto.token, dto.evidenceId);
  }

  /** Streams one of the shopper's OWN evidence photos back (token-guarded;
   *  POST so the token stays out of logged URLs). */
  @Public()
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Post('file')
  @HttpCode(HttpStatus.OK)
  async file(@Body() dto: PublicFileDto, @Res() res: Response) {
    const ev = await this.ms.publicEvidenceFile(dto.token, dto.name);
    if (!isPrivateFileName(ev.name)) {
      throw new NotFoundException({
        code: 'INTERNAL_MS_EVIDENCE_NOT_FOUND',
        message: 'Không tìm thấy ảnh.',
      });
    }
    const path = privateFilePath(ev.name);
    if (!existsSync(path)) {
      throw new NotFoundException({
        code: 'INTERNAL_MS_EVIDENCE_NOT_FOUND',
        message: 'Không tìm thấy ảnh.',
      });
    }
    res
      .status(200)
      .setHeader('Content-Type', ev.mimeType || MIME_BY_EXT[extname(ev.name)] || 'image/jpeg')
      .setHeader('Cache-Control', 'private, max-age=3600')
      .sendFile(path);
  }

  /**
   * Evidence upload (multipart: file + token + kind + optional questionId).
   * Private disk store, crypto-random filename, image-only validation; the
   * file is deleted again if the token turns out invalid, so a bad token
   * can never park bytes on the server.
   */
  @Public()
  @Throttle({ default: { limit: 15, ttl: 60_000 } })
  @Post('upload')
  @HttpCode(HttpStatus.OK)
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (_req, _file, cb) => cb(null, ensurePrivateDir()),
        filename: (_req, file, cb) => cb(null, privateFileName(file.mimetype)),
      }),
      limits: { fileSize: 20 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        // AVIF excluded — the private store's name map covers jpg/png/webp.
        cb(null, ACCEPTED_IMAGE_MIMES.has(file.mimetype) && file.mimetype !== 'image/avif');
      },
    }),
  )
  async upload(
    @UploadedFile() file: Express.Multer.File,
    @Body() body: { token?: string; kind?: string; questionId?: string },
  ) {
    if (!file) {
      throw new BadRequestException({
        code: 'INTERNAL_MS_UPLOAD_NO_FILE',
        message: 'Chưa chọn ảnh (JPG/PNG/WebP).',
      });
    }
    const cleanup = () => {
      try {
        unlinkSync(file.path);
      } catch {
        /* best-effort */
      }
    };
    if (!fileLooksLikeImage(file.path)) {
      cleanup();
      throw new BadRequestException({
        code: 'INTERNAL_MS_UPLOAD_NOT_IMAGE',
        message: 'Tệp tải lên không phải ảnh hợp lệ.',
      });
    }
    const kind = ['RECEIPT', 'PRODUCT', 'PACKAGING', 'ANSWER', 'OTHER'].includes(body.kind ?? '')
      ? (body.kind as 'RECEIPT' | 'PRODUCT' | 'PACKAGING' | 'ANSWER' | 'OTHER')
      : 'OTHER';
    try {
      return await this.ms.publicAttachEvidence({
        rawToken: body.token ?? '',
        kind,
        questionId: body.questionId || undefined,
        name: file.filename,
        mimeType: file.mimetype,
        sizeBytes: file.size,
      });
    } catch (err) {
      // Invalid/expired token or bad question → don't orphan the file.
      cleanup();
      throw err;
    }
  }
}

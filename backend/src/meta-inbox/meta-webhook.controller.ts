import {
  Controller,
  ForbiddenException,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Logger,
  Post,
  Query,
  RawBodyRequest,
  Req,
  Res,
} from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import type { Request, Response } from 'express';

import { Public } from '../auth/decorators/public.decorator';

import { parseMetaWebhook } from './meta-events';
import { MetaInboxService } from './meta-inbox.service';
import { isValidMetaSignature } from './meta-signature';

/**
 * Meta (Messenger + Instagram) webhook — the Callback URL registered in the
 * "Banan Inbox Agent" app: https://api.<domain>/api/v1/webhooks/meta
 *
 * GET  = one-off subscription handshake (echo `hub.challenge` as plain text,
 *        bypassing the JSON envelope, iff `hub.verify_token` matches).
 * POST = events. Signature-checked, acknowledged immediately (Meta retries
 *        and eventually disables slow webhooks), processed in the background.
 */
@ApiExcludeController()
@Controller({ path: 'webhooks/meta', version: '1' })
export class MetaWebhookController {
  private readonly logger = new Logger(MetaWebhookController.name);

  constructor(private readonly inbox: MetaInboxService) {}

  @Public()
  @Get()
  verify(
    @Query('hub.mode') mode: string,
    @Query('hub.verify_token') token: string,
    @Query('hub.challenge') challenge: string,
    @Res() res: Response,
  ): void {
    const expected = process.env.META_VERIFY_TOKEN;
    if (mode === 'subscribe' && expected && token === expected) {
      res.status(200).type('text/plain').send(challenge);
      return;
    }
    this.logger.warn('Meta webhook verification rejected (verify token mismatch)');
    res.sendStatus(403);
  }

  @SkipThrottle()
  @Public()
  @Post()
  @HttpCode(HttpStatus.OK)
  receive(
    @Req() req: RawBodyRequest<Request>,
    @Headers('x-hub-signature-256') signature: string | undefined,
  ): { received: true } {
    const secret = process.env.META_APP_SECRET ?? '';
    if (!req.rawBody || !isValidMetaSignature(req.rawBody, signature, secret)) {
      this.logger.warn('Meta webhook with missing/invalid signature rejected');
      throw new ForbiddenException('Invalid signature');
    }
    this.inbox.handle(parseMetaWebhook(req.body));
    return { received: true };
  }
}

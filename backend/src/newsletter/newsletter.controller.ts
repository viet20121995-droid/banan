import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  Res,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import type { Response } from 'express';

import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { EmailService } from '../notifications/email.service';

import { ListSubscribersDto, SendCampaignDto, SubscribeDto } from './dto';
import { NewsletterService } from './newsletter.service';

@ApiTags('newsletter')
@Controller({ path: 'newsletter', version: '1' })
export class NewsletterController {
  constructor(
    private readonly newsletter: NewsletterService,
    private readonly email: EmailService,
  ) {}

  /// Public subscribe — called from the customer footer + popup. Always
  /// returns 200 (idempotent on already-confirmed addresses).
  @Public()
  @Post('subscribe')
  subscribe(@Body() dto: SubscribeDto) {
    return this.newsletter.subscribe(dto);
  }

  // Confirm / unsubscribe open directly from an email link, so they render a
  // small branded HTML page (handled by the backend) instead of JSON.
  @Public()
  @Get('confirm')
  async confirm(
    @Query('token') token: string,
    @Res() res: Response,
  ): Promise<void> {
    try {
      await this.newsletter.confirm(token);
      res.type('html').send(
        this.page(
          'Đã xác nhận đăng ký 🎉',
          'Cảm ơn bạn! Bạn sẽ nhận khuyến mãi & món mới từ Banan qua email.',
        ),
      );
    } catch {
      res.status(400).type('html').send(
        this.page(
          'Liên kết không hợp lệ',
          'Liên kết xác nhận đã hết hạn hoặc không đúng.',
        ),
      );
    }
  }

  @Public()
  @Get('unsubscribe')
  async unsubscribe(
    @Query('token') token: string,
    @Res() res: Response,
  ): Promise<void> {
    try {
      await this.newsletter.unsubscribe(token);
      res.type('html').send(
        this.page(
          'Đã hủy đăng ký',
          'Bạn sẽ không nhận email tin tức từ Banan nữa. Hẹn gặp lại!',
        ),
      );
    } catch {
      res.status(400).type('html').send(
        this.page(
          'Liên kết không hợp lệ',
          'Liên kết không đúng hoặc đã hết hạn.',
        ),
      );
    }
  }

  /// Minimal branded HTML landing for the email-link click.
  private page(title: string, body: string): string {
    const home = this.email.customerAppBaseUrl;
    return `<!doctype html><html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title} · Banan</title></head><body style="margin:0;background:#FAF6F1;font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;color:#3B2A22;"><div style="max-width:480px;margin:64px auto;padding:0 20px;text-align:center;"><div style="font-family:Georgia,serif;font-size:26px;color:#C9405C;font-weight:700;">Banan</div><h1 style="font-size:22px;margin:24px 0 12px;">${title}</h1><p style="font-size:15px;line-height:1.6;color:#6B5A52;">${body}</p><a href="${home}" style="display:inline-block;margin-top:24px;padding:12px 28px;background:#C9405C;color:#fff;border-radius:24px;text-decoration:none;font-weight:600;">Về trang chủ</a></div></body></html>`;
  }
}

@ApiBearerAuth()
@ApiTags('merchant.newsletter')
@Controller({ path: 'merchant/newsletter', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.ADMIN)
export class MerchantNewsletterController {
  constructor(private readonly newsletter: NewsletterService) {}

  @Get()
  list(@Query() q: ListSubscribersDto) {
    return this.newsletter.list(q);
  }

  @Get('export.csv')
  async exportCsv(@Res() res: Response): Promise<void> {
    const csv = await this.newsletter.exportActiveCsv();
    const filename = `banan-newsletter-${new Date()
      .toISOString()
      .slice(0, 10)}.csv`;
    res.set({
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': `attachment; filename="${filename}"`,
    });
    // UTF-8 BOM so Excel opens it without garbled diacritics.
    res.end('﻿' + csv);
  }

  /// Compose + send a newsletter campaign by email (+ optional in-app push).
  @Post('send')
  send(@Body() dto: SendCampaignDto) {
    return this.newsletter.sendCampaign(dto);
  }
}

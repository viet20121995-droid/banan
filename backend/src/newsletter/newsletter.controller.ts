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

import { ListSubscribersDto, SubscribeDto } from './dto';
import { NewsletterService } from './newsletter.service';

@ApiTags('newsletter')
@Controller({ path: 'newsletter', version: '1' })
export class NewsletterController {
  constructor(private readonly newsletter: NewsletterService) {}

  /// Public subscribe — called from the customer footer + popup. Always
  /// returns 200 (idempotent on already-confirmed addresses).
  @Public()
  @Post('subscribe')
  subscribe(@Body() dto: SubscribeDto) {
    return this.newsletter.subscribe(dto);
  }

  @Public()
  @Get('confirm')
  confirm(@Query('token') token: string) {
    return this.newsletter.confirm(token);
  }

  @Public()
  @Get('unsubscribe')
  unsubscribe(@Query('token') token: string) {
    return this.newsletter.unsubscribe(token);
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
}

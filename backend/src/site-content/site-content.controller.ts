import { Body, Controller, Get, HttpCode, HttpStatus, Param, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';

import { UpdateSiteContentDto } from './dto';
import { SiteContentService } from './site-content.service';

@ApiTags('site-content')
@Controller({ path: 'site-content', version: '1' })
export class SiteContentController {
  constructor(private readonly content: SiteContentService) {}

  /// Public read — customer app fetches FAQ / About here.
  @Public()
  @Get(':key')
  get(@Param('key') key: string) {
    return this.content.get(key);
  }
}

@ApiBearerAuth()
@ApiTags('merchant.site-content')
@Controller({ path: 'merchant/site-content', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.ADMIN)
export class MerchantSiteContentController {
  constructor(private readonly content: SiteContentService) {}

  @Get(':key')
  get(@Param('key') key: string) {
    return this.content.get(key);
  }

  // FAQ / About are chain-wide singletons served publicly to all customers,
  // so writes are ADMIN-only — a MERCHANT_OWNER must not edit/deface global
  // site content. (GET stays readable to merchant.)
  @Roles(Role.ADMIN)
  @Patch(':key')
  @HttpCode(HttpStatus.OK)
  update(@Param('key') key: string, @Body() dto: UpdateSiteContentDto) {
    return this.content.update(key, dto.data);
  }
}

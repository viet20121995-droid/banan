import { Body, Controller, Get, HttpCode, HttpStatus, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';

import { UpdateMarketingDto } from './dto';
import { MarketingService } from './marketing.service';

@ApiTags('marketing')
@Controller({ path: 'marketing', version: '1' })
export class MarketingController {
  constructor(private readonly marketing: MarketingService) {}

  /// Public — customer app reads flags to show/hide each program surface.
  @Public()
  @Get('config')
  get() {
    return this.marketing.get();
  }
}

@ApiBearerAuth()
@ApiTags('merchant.marketing')
@Controller({ path: 'merchant/marketing', version: '1' })
@Roles(Role.ADMIN, Role.MERCHANT_OWNER)
export class MerchantMarketingController {
  constructor(private readonly marketing: MarketingService) {}

  @Get('config')
  get() {
    return this.marketing.get();
  }

  @Patch('config')
  @HttpCode(HttpStatus.OK)
  update(@Body() dto: UpdateMarketingDto) {
    return this.marketing.update(dto);
  }
}

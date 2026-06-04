import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import { AnalyticsService } from './analytics.service';

@ApiBearerAuth()
@ApiTags('merchant.analytics')
@Controller({ path: 'merchant/analytics', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
export class MerchantAnalyticsController {
  constructor(private readonly analytics: AnalyticsService) {}

  @Get('summary')
  summary(
    @CurrentUser() user: AuthPrincipal,
    @Query('range') rangeRaw?: string,
  ) {
    if (!user.storeId && user.role !== Role.ADMIN) {
      throw new BadRequestException({ code: 'NO_STORE_ASSIGNED' });
    }
    const range = this.analytics.parseRange(rangeRaw);
    return this.analytics.merchantSummary(user.storeId ?? null, range);
  }
}

@ApiBearerAuth()
@ApiTags('kitchen.analytics')
@Controller({ path: 'kitchen/analytics', version: '1' })
@Roles(Role.KITCHEN_MANAGER, Role.KITCHEN_STAFF, Role.ADMIN)
export class KitchenAnalyticsController {
  constructor(private readonly analytics: AnalyticsService) {}

  @Get('summary')
  summary(
    @CurrentUser() user: AuthPrincipal,
    @Query('range') rangeRaw?: string,
  ) {
    if (!user.kitchenId && user.role !== Role.ADMIN) {
      throw new BadRequestException({ code: 'NO_KITCHEN_ASSIGNED' });
    }
    const range = this.analytics.parseRange(rangeRaw);
    return this.analytics.kitchenSummary(user.kitchenId!, range);
  }
}

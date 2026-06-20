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
    @Query('storeId') storeIdRaw?: string,
  ) {
    if (!user.storeId && user.role !== Role.ADMIN) {
      throw new BadRequestException({ code: 'NO_STORE_ASSIGNED' });
    }
    const range = this.analytics.parseRange(rangeRaw);
    // Merchants are locked to their own store; admin may optionally scope to
    // one branch (else null = whole chain, with the per-branch breakdown).
    const scopeStoreId =
      user.storeId ?? (storeIdRaw && storeIdRaw.trim() ? storeIdRaw.trim() : null);
    return this.analytics.merchantSummary(scopeStoreId, range);
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
    @Query('kitchenId') kitchenIdParam?: string,
  ) {
    // Admin must name the kitchen via ?kitchenId=; staff are pinned to theirs.
    // Never pass an undefined kitchenId to the query (it would silently read
    // every kitchen's orders).
    const kitchenId = user.role === Role.ADMIN ? kitchenIdParam : user.kitchenId;
    if (!kitchenId) {
      throw new BadRequestException({
        code: 'NO_KITCHEN_ASSIGNED',
        message:
          user.role === Role.ADMIN
            ? 'Admin cần truyền ?kitchenId= để xem báo cáo một bếp.'
            : 'Tài khoản chưa được gán bếp.',
      });
    }
    const range = this.analytics.parseRange(rangeRaw);
    return this.analytics.kitchenSummary(kitchenId, range);
  }
}

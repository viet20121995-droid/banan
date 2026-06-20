import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';
import { merchantStoreScope } from '../common/merchant-scope';

import { BundlesService } from './bundles.service';
import { CreateBundleDto, UpdateBundleDto } from './dto';

@ApiTags('bundles')
@Controller({ path: 'bundles', version: '1' })
export class BundlesController {
  constructor(private readonly bundles: BundlesService) {}

  @Public()
  @Get()
  list() {
    return this.bundles.list();
  }

  /// Pinned-to-home subset — customer home page renders these as a
  /// "Combo nổi bật" carousel.
  @Public()
  @Get('home')
  home() {
    return this.bundles.homePinned();
  }

  @Public()
  @Get(':id')
  async detail(@Param('id') id: string) {
    const bundle = await this.bundles.findOne(id);
    const savedVnd = await this.bundles.savings(id);
    return { ...bundle, savedVnd };
  }
}

@ApiBearerAuth()
@ApiTags('merchant.bundles')
@Controller({ path: 'merchant/bundles', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.ADMIN)
export class MerchantBundlesController {
  constructor(private readonly bundles: BundlesService) {}

  /// Admin scope = chain-wide (null); merchants scope to their own store; a
  /// merchant with no store is rejected (NO_STORE_ASSIGNED) rather than
  /// silently getting the chain-wide branch.
  private scope(user: AuthPrincipal): string | null {
    return merchantStoreScope(user);
  }

  @Get()
  list(@CurrentUser() user: AuthPrincipal) {
    return this.bundles.listForMerchant(this.scope(user));
  }

  @Get(':id')
  findOne(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.bundles.findOneForMerchant(id, this.scope(user));
  }

  // Combos are chain-wide catalog content, managed by admin only. New ones
  // attach to the catalog store; admin (scope null) may edit/delete any.
  // Merchants keep read-only list/view above but the UI hides Combo entirely.
  @Roles(Role.ADMIN)
  @Post()
  async create(@CurrentUser() _user: AuthPrincipal, @Body() dto: CreateBundleDto) {
    const storeId = await this.bundles.catalogStoreId();
    return this.bundles.create(storeId, dto);
  }

  @Roles(Role.ADMIN)
  @Patch(':id')
  update(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: UpdateBundleDto,
  ) {
    return this.bundles.update(id, this.scope(user), dto);
  }

  @Roles(Role.ADMIN)
  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':id')
  async remove(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    await this.bundles.remove(id, this.scope(user));
  }
}

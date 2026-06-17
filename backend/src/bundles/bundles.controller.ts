import {
  BadRequestException,
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

  // A combo belongs to exactly one store, so creation is a store-owner
  // operation — admin (no implicit store) is excluded here rather than
  // crashing with a 500 when it lacks a storeId. The merchant UI already
  // hides Combo management from admin.
  @Roles(Role.MERCHANT_OWNER)
  @Post()
  create(@CurrentUser() user: AuthPrincipal, @Body() dto: CreateBundleDto) {
    if (!user.storeId) {
      throw new BadRequestException({
        code: 'NO_STORE_ASSIGNED',
        message: 'Tài khoản chưa được gán cửa hàng — combo phải thuộc một cửa hàng cụ thể.',
      });
    }
    return this.bundles.create(user.storeId, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: UpdateBundleDto,
  ) {
    return this.bundles.update(id, this.scope(user), dto);
  }

  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':id')
  async remove(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    await this.bundles.remove(id, this.scope(user));
  }
}

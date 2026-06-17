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
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import { StoresService } from './stores.service';

class UpdateStoreSettingsDto {
  @IsOptional()
  @IsBoolean()
  isPaused?: boolean;

  @IsOptional()
  @IsBoolean()
  isPickupPaused?: boolean;

  @IsOptional()
  @IsBoolean()
  isDeliveryPaused?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  pauseReason?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  minOrderVnd?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  defaultLeadHours?: number;

  /// Weekly hours map keyed by lowercase short day: mon/tue/.../sun.
  /// Value is an array of [open, close] HH:MM string pairs (multiple
  /// windows per day allowed for split shifts). Pass null/{} for 24/7.
  @IsOptional()
  @IsObject()
  openingHours?: Record<string, [string, string][]>;
}

class CreateBlackoutDto {
  /// ISO date (YYYY-MM-DD). Stored as UTC-midnight DATE column.
  @IsDateString()
  date!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  reason?: string;
}

class CreateManyBlackoutsDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateBlackoutDto)
  dates!: CreateBlackoutDto[];
}

@ApiTags('stores')
@Controller({ path: 'stores', version: '1' })
export class StoresController {
  constructor(private readonly stores: StoresService) {}

  /** Public — anyone (incl. guests) can list branches. */
  @Public()
  @Get()
  findAll() {
    return this.stores.findAll();
  }
}

/// Merchant-facing controls over the cửa hàng's operating rules.
/// Every endpoint scopes to the caller's own `user.storeId`; an admin with no
/// store assigned is rejected (NO_STORE_ASSIGNED) — there is no store-targeting
/// path param, so admin must act through a store-owner account.
@ApiBearerAuth()
@ApiTags('merchant.store')
@Controller({ path: 'merchant/store', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
export class MerchantStoreController {
  constructor(private readonly stores: StoresService) {}

  private scope(user: AuthPrincipal): string {
    if (!user.storeId) {
      throw new BadRequestException({ code: 'NO_STORE_ASSIGNED' });
    }
    return user.storeId;
  }

  @Get('settings')
  getSettings(@CurrentUser() user: AuthPrincipal) {
    return this.stores.getSettings(this.scope(user));
  }

  @Patch('settings')
  updateSettings(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: UpdateStoreSettingsDto,
  ) {
    return this.stores.updateSettings(this.scope(user), dto);
  }

  @Get('blackouts')
  listBlackouts(@CurrentUser() user: AuthPrincipal) {
    return this.stores.listBlackouts(this.scope(user));
  }

  @Post('blackouts')
  addBlackout(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: CreateBlackoutDto,
  ) {
    return this.stores.addBlackout(this.scope(user), dto.date, dto.reason);
  }

  /// Batch add — convenient for marking Tết holidays in one request.
  @Post('blackouts/bulk')
  addBlackoutsBulk(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: CreateManyBlackoutsDto,
  ) {
    return this.stores.addBlackoutsBulk(this.scope(user), dto.dates);
  }

  @Delete('blackouts/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  removeBlackout(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
  ) {
    return this.stores.removeBlackout(this.scope(user), id);
  }
}

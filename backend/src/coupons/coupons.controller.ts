import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';
import { CouponType, Role } from '@prisma/client';

import { CouponsService } from './coupons.service';

class ValidateCouponDto {
  @IsString()
  @MinLength(2)
  @MaxLength(40)
  code!: string;

  @IsInt()
  @Min(0)
  subtotal!: number;

  @IsInt()
  @Min(0)
  deliveryFee!: number;
}

@ApiBearerAuth()
@ApiTags('coupons')
@Controller({ path: 'coupons', version: '1' })
@Roles(Role.CUSTOMER, Role.ADMIN)
export class CouponsController {
  constructor(private readonly coupons: CouponsService) {}

  /** Customer enters a code at checkout — server validates + returns the discount. */
  @Post('validate')
  async validate(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: ValidateCouponDto,
  ) {
    const result = await this.coupons.validate({
      code: dto.code,
      subtotalVnd: dto.subtotal,
      deliveryFeeVnd: dto.deliveryFee,
      userId: user.sub,
    });
    return {
      code: result.coupon.code,
      type: result.coupon.type,
      value: result.coupon.value.toString(),
      discount: result.discountVnd,
      appliesToDelivery: result.appliesToDelivery,
    };
  }
}

class CreateCouponDto {
  @IsString()
  @MinLength(3)
  @MaxLength(40)
  code!: string;

  @IsEnum(CouponType)
  type!: CouponType;

  @IsInt()
  @Min(1)
  value!: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  minSubtotalVnd?: number;

  @IsDateString()
  startsAt!: string;

  @IsDateString()
  endsAt!: string;

  /** Total redemptions across all customers. Omit / 0 = unlimited (shared). */
  @IsOptional()
  @IsInt()
  @Min(1)
  maxRedemptions?: number;

  /** Per-customer cap. 1 = single-use per customer. */
  @IsInt()
  @Min(1)
  perUserLimit!: number;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  label?: string;
}

class UpdateCouponDto {
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsDateString()
  endsAt?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  maxRedemptions?: number;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  label?: string;
}

@ApiBearerAuth()
@ApiTags('merchant.coupons')
@Controller({ path: 'merchant/coupons', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
export class MerchantCouponsController {
  constructor(private readonly coupons: CouponsService) {}

  private scope(user: AuthPrincipal): string | null {
    if (user.role === Role.ADMIN) return null;
    if (!user.storeId) {
      throw new BadRequestException({ code: 'NO_STORE_ASSIGNED' });
    }
    return user.storeId;
  }

  @Get()
  list(@CurrentUser() user: AuthPrincipal) {
    return this.coupons.listForStore(this.scope(user));
  }

  @Post()
  create(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: CreateCouponDto,
  ) {
    return this.coupons.createForStore(this.scope(user), dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: UpdateCouponDto,
  ) {
    return this.coupons.updateForStore(this.scope(user), id, dto);
  }
}

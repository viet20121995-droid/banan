import { Body, Controller, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsInt, IsString, MaxLength, Min, MinLength } from 'class-validator';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';
import { Role } from '@prisma/client';

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

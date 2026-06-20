import { BadRequestException, Body, Controller, Get, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';

import { DeliveryConfigService } from './delivery-config.service';
import { findWard, HCM_WARDS } from './hcm-wards';
import { StoreRouterService } from './store-router.service';

class QuoteRequestDto {
  /// HCMC ward catalog code. Omit for a base-only quote.
  @IsOptional()
  @IsString()
  @MaxLength(60)
  wardCode?: string;

  /// Cart product ids — used to detect birthday-cake collection items so
  /// the right fee tier is applied. Empty list = standard tier.
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(40)
  @IsUUID('4', { each: true })
  productIds?: string[];
}

class UpdateDeliveryConfigDto {
  @IsOptional()
  @IsInt()
  @Min(0)
  standardFeeSameWardVnd?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  standardFeeOtherWardVnd?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  birthdayCakeFeeSameWardVnd?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  birthdayCakeFeeOtherWardVnd?: number;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  birthdayCakeCollectionSlug?: string;
}

@ApiTags('geo')
@Controller({ path: 'geo', version: '1' })
export class GeoController {
  constructor(
    private readonly router: StoreRouterService,
    private readonly config: DeliveryConfigService,
  ) {}

  /// Catalog of HCMC wards (post-2025 reform).
  @Public()
  @Get('hcm-wards')
  hcmWards() {
    return HCM_WARDS.map((w) => ({
      code: w.code,
      name: w.name,
      lat: w.lat,
      lng: w.lng,
      oldArea: w.oldArea ?? null,
    }));
  }

  /// Live delivery-fee quote. New rule (2026-05): fee depends on whether
  /// the customer ward matches the routed store's ward — same ward ⇒
  /// cheap (or free), other ward ⇒ flat surcharge. Distance is still
  /// computed for display ("Khoảng cách: 3.4 km") but not used for the
  /// fee math itself.
  @Public()
  @Post('delivery-quote')
  async deliveryQuote(@Body() dto: QuoteRequestDto) {
    const cfg = await this.config.get();
    const productIds = dto.productIds ?? [];
    const hasBirthdayCake = await this.config.cartHasBirthdayCake(productIds, cfg);

    // No ward yet — show the "same ward" fee (best case) as a teaser so
    // the customer has something to read until they pick a phường.
    if (!dto.wardCode) {
      const fee = hasBirthdayCake ? cfg.birthdayCakeFeeSameWardVnd : cfg.standardFeeSameWardVnd;
      return {
        ...this._breakdown(fee, hasBirthdayCake, 'same'),
        distanceKm: null as number | null,
        wardKnown: false,
        store: null as null | {
          id: string;
          name: string;
          address: string;
          wardCode: string | null;
        },
      };
    }

    const ward = findWard(dto.wardCode);
    if (!ward) {
      throw new BadRequestException({ code: 'WARD_NOT_FOUND' });
    }
    const routed = await this.router.pickNearestForPoint(ward);
    if (!routed) {
      const fee = hasBirthdayCake ? cfg.birthdayCakeFeeOtherWardVnd : cfg.standardFeeOtherWardVnd;
      return {
        ...this._breakdown(fee, hasBirthdayCake, 'other'),
        distanceKm: null,
        wardKnown: true,
        store: null,
        noStoreAvailable: true,
      };
    }
    const sameWard = routed.storeWardCode != null && routed.storeWardCode === dto.wardCode;
    const fee = this.config.feeFor(cfg, dto.wardCode, routed.storeWardCode, hasBirthdayCake);
    return {
      ...this._breakdown(fee, hasBirthdayCake, sameWard ? 'same' : 'other'),
      distanceKm: Math.round(routed.distanceKm * 10) / 10,
      wardKnown: true,
      store: {
        id: routed.storeId,
        name: routed.storeName,
        address: routed.storeAddress,
        wardCode: routed.storeWardCode,
      },
    };
  }

  /// Shared shape — keeps the breakdown explicit so the customer sees
  /// exactly which tier applies and why.
  private _breakdown(feeVnd: number, hasBirthdayCake: boolean, band: 'same' | 'other') {
    return {
      totalVnd: feeVnd,
      tier: hasBirthdayCake ? ('birthdayCake' as const) : ('standard' as const),
      // Kept the legacy "under"/"over" keys for backward compatibility
      // with already-shipped Flutter builds; new clients should switch
      // to checking `wardMatch` instead.
      band: band === 'same' ? ('under' as const) : ('over' as const),
      wardMatch: band,
      hasBirthdayCake,
    };
  }

  // ── Admin-only config endpoints ────────────────────────────────────────

  @ApiBearerAuth()
  @Roles(Role.ADMIN)
  @Get('delivery-config')
  getConfig() {
    return this.config.get();
  }

  @ApiBearerAuth()
  @Roles(Role.ADMIN)
  @Patch('delivery-config')
  updateConfig(@Body() dto: UpdateDeliveryConfigDto) {
    return this.config.update(dto);
  }
}

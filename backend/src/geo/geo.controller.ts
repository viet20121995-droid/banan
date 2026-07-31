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
import {
  canonicalWardCode,
  findWard,
  FORMER_HCMC_WARDS,
  isAmbiguousLegacyWard,
  isFormerHcmcWard,
  isWardServiceable,
  LEGACY_WARD_ALIASES,
} from './hcm-wards';
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

  /// Customer delivery-address catalog. The backend retains all 168 current
  /// units, but Banan only delivers within the 102 units formed from the
  /// pre-merger TP.HCM footprint.
  @Public()
  @Get('hcm-wards')
  hcmWards() {
    const legacyByCanonical = new Map<string, string[]>();
    for (const [legacy, canonical] of Object.entries(LEGACY_WARD_ALIASES)) {
      const list = legacyByCanonical.get(canonical) ?? [];
      list.push(legacy);
      legacyByCanonical.set(canonical, list);
    }
    return FORMER_HCMC_WARDS.map((w) => ({
      code: w.code,
      name: w.name,
      type: w.type,
      lat: w.lat,
      lng: w.lng,
      oldArea: w.oldArea ?? null,
      serviceable: isWardServiceable(w),
      legacyCodes: legacyByCanonical.get(w.code) ?? [],
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

    // A split pre-reform ward can't be auto-mapped — tell the client to ask
    // the customer for a fresh pick instead of guessing a fee.
    if (isAmbiguousLegacyWard(dto.wardCode)) {
      throw new BadRequestException({ code: 'WARD_RESELECTION_REQUIRED' });
    }
    const ward = findWard(dto.wardCode);
    if (!ward) {
      throw new BadRequestException({ code: 'WARD_NOT_FOUND' });
    }
    if (!isFormerHcmcWard(ward)) {
      throw new BadRequestException({ code: 'WARD_OUTSIDE_DELIVERY_AREA' });
    }
    // Valid ward, but no verified centroid yet → outside the delivery zone.
    // NOT an error: the picker must keep listing it; checkout shows "chưa
    // hỗ trợ giao đến khu vực này" and blocks delivery (pickup still fine).
    if (!isWardServiceable(ward)) {
      const fee = hasBirthdayCake ? cfg.birthdayCakeFeeOtherWardVnd : cfg.standardFeeOtherWardVnd;
      return {
        ...this._breakdown(fee, hasBirthdayCake, 'other'),
        distanceKm: null as number | null,
        wardKnown: true,
        serviceable: false,
        store: null,
      };
    }
    const routed = await this.router.pickNearestForPoint({ lat: ward.lat!, lng: ward.lng! });
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
    const fee = this.config.feeFor(cfg, dto.wardCode, routed.storeWardCode, hasBirthdayCake);
    // Compare via canonical codes so a saved address carrying a legacy alias
    // (e.g. `cau-kho`) still counts as "same ward" as a store in the merged
    // ward (`cau-ong-lanh`).
    const sameWard =
      routed.storeWardCode != null &&
      canonicalWardCode(routed.storeWardCode) === canonicalWardCode(dto.wardCode);
    return {
      ...this._breakdown(fee, hasBirthdayCake, sameWard ? 'same' : 'other'),
      distanceKm: Math.round(routed.distanceKm * 10) / 10,
      wardKnown: true,
      serviceable: true,
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

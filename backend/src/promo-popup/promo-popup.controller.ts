import { Body, Controller, Get, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { IsBoolean, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';

import { PromoPopupService } from './promo-popup.service';

class UpdatePromoPopupDto {
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  body?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  imageUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  ctaLabel?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  ctaUrl?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(120)
  countdownSeconds?: number;
}

@ApiTags('promo-popup')
@Controller({ path: 'promo-popup', version: '1' })
export class PromoPopupController {
  constructor(private readonly svc: PromoPopupService) {}

  /// Public read — every customer page load hits this. Returns the popup
  /// regardless of `isActive`; client decides whether to render based on
  /// the active flag + the dismissed-version cookie / localStorage.
  @Public()
  @Get()
  async getPublic() {
    const p = await this.svc.get();
    return {
      isActive: p.isActive,
      title: p.title,
      body: p.body,
      imageUrl: p.imageUrl,
      ctaLabel: p.ctaLabel,
      ctaUrl: p.ctaUrl,
      countdownSeconds: p.countdownSeconds,
      version: p.version,
    };
  }
}

/// Merchant + admin editor surface — both roles need to manage the popup
/// (admin runs chain-wide campaigns, merchant owners surface store news).
@ApiBearerAuth()
@ApiTags('admin.promo-popup')
@Controller({ path: 'admin/promo-popup', version: '1' })
@Roles(Role.ADMIN, Role.MERCHANT_OWNER)
export class AdminPromoPopupController {
  constructor(private readonly svc: PromoPopupService) {}

  @Get()
  get() {
    return this.svc.get();
  }

  // The popup is a single chain-wide record shown to ALL customers, so writes
  // are ADMIN-only — a MERCHANT_OWNER must not mutate it or force a re-display
  // chain-wide. (GET stays readable to merchant for a preview.)
  @Roles(Role.ADMIN)
  @Patch()
  update(@Body() dto: UpdatePromoPopupDto) {
    return this.svc.update(dto);
  }

  /// Force a re-display for every customer — bumps `version`. The frontend
  /// stores the last seen version per device; bumping it surfaces the
  /// popup again even for customers who previously dismissed.
  @Roles(Role.ADMIN)
  @Post('bump')
  bump() {
    return this.svc.update({ bumpVersion: true });
  }
}

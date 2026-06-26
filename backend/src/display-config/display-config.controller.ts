import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString, MaxLength } from 'class-validator';
import { Role } from '@prisma/client';

import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';

import { DisplayConfigService } from './display-config.service';

class UpdateDisplayConfigDto {
  @IsOptional()
  @IsBoolean()
  showStockToCustomers?: boolean;

  // Empty string from the merchant form means "clear it" — we accept the
  // empty value and the service normalises it to null before persisting.
  @IsOptional()
  @IsString()
  @MaxLength(20)
  contactPhone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  contactZaloOaId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  contactMessengerId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  contactEmail?: string;
}

@ApiTags('display-config')
@Controller({ path: 'display-config', version: '1' })
export class DisplayConfigController {
  constructor(private readonly cfg: DisplayConfigService) {}

  /// Public — every customer client fetches this on app boot to decide
  /// whether to render stock badges. Cached for the session.
  @Public()
  @Get()
  get() {
    return this.cfg.get();
  }

  // DisplayConfig is a chain-wide singleton (contact info + stock toggle shown
  // to every customer), so writes are ADMIN-only — a MERCHANT_OWNER must not
  // change the global contact widget for all stores.
  @Roles(Role.ADMIN)
  @Patch()
  update(@Body() dto: UpdateDisplayConfigDto) {
    return this.cfg.update(dto);
  }
}

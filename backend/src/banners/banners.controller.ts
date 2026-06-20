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
import { IsBoolean, IsInt, IsOptional, IsString, MaxLength, Min, MinLength } from 'class-validator';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import { BannersService } from './banners.service';

class CreateBannerDto {
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  imageUrl!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  ctaUrl?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;
}

class UpdateBannerDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  imageUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  ctaUrl?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

@ApiTags('banners')
@Controller({ path: 'banners', version: '1' })
export class BannersController {
  constructor(private readonly banners: BannersService) {}

  /** Public — drives the customer home hero carousel. */
  @Public()
  @Get()
  list() {
    return this.banners.listPublic();
  }
}

@ApiBearerAuth()
@ApiTags('merchant.banners')
@Controller({ path: 'merchant/banners', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
export class MerchantBannersController {
  constructor(private readonly banners: BannersService) {}

  private scope(user: AuthPrincipal): string | null {
    if (user.role === Role.ADMIN) return null;
    if (!user.storeId) {
      throw new BadRequestException({ code: 'NO_STORE_ASSIGNED' });
    }
    return user.storeId;
  }

  @Get()
  list(@CurrentUser() user: AuthPrincipal) {
    return this.banners.listForStore(this.scope(user));
  }

  @Post()
  create(@CurrentUser() user: AuthPrincipal, @Body() dto: CreateBannerDto) {
    return this.banners.create(this.scope(user), dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: UpdateBannerDto,
  ) {
    return this.banners.update(this.scope(user), id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.banners.remove(this.scope(user), id);
  }
}

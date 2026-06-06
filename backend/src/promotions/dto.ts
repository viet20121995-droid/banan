import { CampaignType } from '@prisma/client';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateCampaignDto {
  @IsEnum(CampaignType)
  type!: CampaignType;

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name!: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsInt()
  priority?: number;

  @IsOptional()
  @IsBoolean()
  stackable?: boolean;

  @IsOptional()
  @IsDateString()
  startsAt?: string;

  @IsOptional()
  @IsDateString()
  endsAt?: string;

  /// Type-specific settings, e.g.
  ///  PRODUCT_DISCOUNT  { kind:'PERCENT'|'FIXED', value, productIds:[] }
  ///  CATEGORY_DISCOUNT { kind, value, categoryIds:[] }
  ///  FLASH_SALE        { kind, value, productIds?:[], categoryIds?:[] }
  ///  HAPPY_HOUR        { kind, value, productIds?, categoryIds?, daysOfWeek?:[0-6], startTime:'HH:MM', endTime:'HH:MM' }
  @IsObject()
  config!: Record<string, unknown>;

  @IsOptional()
  @IsUUID()
  storeId?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  usageLimit?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  perUserLimit?: number;
}

export class UpdateCampaignDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsInt()
  priority?: number;

  @IsOptional()
  @IsBoolean()
  stackable?: boolean;

  @IsOptional()
  @IsDateString()
  startsAt?: string;

  @IsOptional()
  @IsDateString()
  endsAt?: string;

  @IsOptional()
  @IsObject()
  config?: Record<string, unknown>;

  @IsOptional()
  @IsUUID()
  storeId?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  usageLimit?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  perUserLimit?: number;
}

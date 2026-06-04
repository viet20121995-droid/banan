import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

import { VariantInputDto } from './variant.dto';

export class CreateProductDto {
  @IsUUID()
  categoryId!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(160)
  slug!: string;

  @IsString()
  description!: string;

  @IsNumber()
  @Min(0)
  basePrice!: number;

  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(10)
  images: string[] = [];

  /** Free-form merchant-set badges shown on the customer card. */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(8)
  tags?: string[];

  @IsOptional()
  @IsInt()
  @Min(0)
  preparationMinutes?: number;

  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;

  @IsOptional()
  @IsBoolean()
  isSeasonal?: boolean;

  @IsOptional()
  @IsDateString()
  seasonStart?: string;

  @IsOptional()
  @IsDateString()
  seasonEnd?: string;

  /// Per-product advance-notice override (hours). Null = use store default.
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(720)
  leadTimeHours?: number | null;

  /// Days of week the product is sold. Empty = every day. Int values follow
  /// JS Date.getDay() (0=Sun..6=Sat). Used for "trà chiều chỉ T2-T6" kind of
  /// rules.
  @IsOptional()
  @IsArray()
  @IsInt({ each: true })
  @IsIn([0, 1, 2, 3, 4, 5, 6], { each: true })
  @ArrayUnique()
  @ArrayMaxSize(7)
  availableDaysOfWeek?: number[];

  /// Hard cap on total quantity ordered per day for this product. Null =
  /// unlimited.
  @IsOptional()
  @IsInt()
  @Min(1)
  dailyMaxQuantity?: number | null;

  /// Macaron-set flavour composer. When set, the customer picks exactly
  /// this many flavours from [flavorOptions] (repeats allowed) at
  /// checkout. Null = no composer.
  @IsOptional()
  @IsInt()
  @Min(2)
  @Max(50)
  flavorPickCount?: number | null;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(50)
  flavorOptions?: string[];

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => VariantInputDto)
  @ArrayMinSize(1)
  variants!: VariantInputDto[];
}

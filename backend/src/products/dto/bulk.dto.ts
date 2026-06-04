import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

/** One row of a CSV product import. Category resolved by id or by name. */
export class BulkImportRowDto {
  @IsString()
  @MaxLength(200)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  slug?: string;

  @IsOptional()
  @IsString()
  categoryId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  categoryName?: string;

  @IsNumber()
  @Min(0)
  basePrice!: number;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  imageUrl?: string;
}

export class BulkImportDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => BulkImportRowDto)
  rows!: BulkImportRowDto[];
}

/** Bulk price adjustment over a scope of the catalog. */
export class BulkPriceDto {
  @IsEnum(['all', 'category', 'collection'])
  scope!: 'all' | 'category' | 'collection';

  @IsOptional()
  @IsString()
  categoryId?: string;

  @IsOptional()
  @IsString()
  collectionSlug?: string;

  @IsEnum(['percent', 'fixed'])
  mode!: 'percent' | 'fixed';

  /// percent mode: +10 / -10 (%). fixed mode: +5000 / -5000 (VND).
  @IsNumber()
  @Min(-1_000_000_000)
  @Max(1_000_000_000)
  amount!: number;

  /// Round the resulting price to the nearest multiple (e.g. 1000 VND).
  @IsOptional()
  @IsNumber()
  @Min(0)
  roundTo?: number;

  /// When true, only compute + return the preview without writing.
  @IsOptional()
  dryRun?: boolean;
}

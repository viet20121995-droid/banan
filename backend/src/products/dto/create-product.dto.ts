import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
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

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => VariantInputDto)
  @ArrayMinSize(1)
  variants!: VariantInputDto[];
}

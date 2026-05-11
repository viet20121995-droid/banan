import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class CollectionItemInputDto {
  @IsUUID()
  productId!: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;
}

export class CreateCollectionDto {
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(80)
  slug!: string;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  description?: string;

  @IsOptional()
  @IsString()
  imageUrl?: string;

  @IsOptional()
  @IsBoolean()
  isPinnedToHome?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(60)
  @ValidateNested({ each: true })
  @Type(() => CollectionItemInputDto)
  items?: CollectionItemInputDto[];
}

export class UpdateCollectionDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  slug?: string;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  description?: string;

  @IsOptional()
  @IsString()
  imageUrl?: string;

  @IsOptional()
  @IsBoolean()
  isPinnedToHome?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  /** When provided, replaces the full item set (diff-update). */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(60)
  @ValidateNested({ each: true })
  @Type(() => CollectionItemInputDto)
  items?: CollectionItemInputDto[];
}

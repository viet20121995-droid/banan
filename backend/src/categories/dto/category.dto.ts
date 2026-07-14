import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateCategoryDto {
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
  imageUrl?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  isPinnedToHome?: boolean;

  @IsOptional()
  @IsBoolean()
  isBirthdayCakeCategory?: boolean;

  @IsOptional()
  @IsBoolean()
  isHidden?: boolean;
}

/** New display order: the full list of category ids in the desired order. */
export class ReorderCategoriesDto {
  @IsArray()
  @ArrayMaxSize(500)
  @IsString({ each: true })
  ids!: string[];
}

export class UpdateCategoryDto {
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
  imageUrl?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  isPinnedToHome?: boolean;

  @IsOptional()
  @IsBoolean()
  isBirthdayCakeCategory?: boolean;

  @IsOptional()
  @IsBoolean()
  isHidden?: boolean;
}

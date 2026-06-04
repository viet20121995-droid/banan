import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateThreadDto {
  @IsString()
  @MinLength(1)
  @MaxLength(140)
  title!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(4000)
  body!: string;

  @IsOptional()
  @IsString()
  imageUrl?: string;

  /** Carousel images (first = cover). Up to 10. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  images?: string[];

  /** Optional product to deep-link with a "Shop this" button. */
  @IsOptional()
  @IsUUID()
  productId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  ctaLabel?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  ctaUrl?: string;

  /** ISO date — when set + future, scheduler auto-publishes then. */
  @IsOptional()
  @IsDateString()
  scheduledPublishAt?: string;

  /** When true, set publishedAt = now(). When false (or omitted), draft. */
  @IsOptional()
  @IsBoolean()
  publish?: boolean;
}

export class UpdateThreadDto {
  @IsOptional()
  @IsString()
  @MaxLength(140)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  body?: string;

  @IsOptional()
  @IsString()
  imageUrl?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  images?: string[];

  @IsOptional()
  @IsUUID()
  productId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  ctaLabel?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  ctaUrl?: string;

  @IsOptional()
  @IsDateString()
  scheduledPublishAt?: string;

  /** Tri-state: true = publish (or re-publish), false = unpublish. */
  @IsOptional()
  @IsBoolean()
  publish?: boolean;
}

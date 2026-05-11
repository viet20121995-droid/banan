import {
  IsBoolean,
  IsOptional,
  IsString,
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

  /** When true, set publishedAt = now(). When false (or omitted), saves as draft. */
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

  /** Tri-state: true = publish (or re-publish), false = unpublish. */
  @IsOptional()
  @IsBoolean()
  publish?: boolean;
}

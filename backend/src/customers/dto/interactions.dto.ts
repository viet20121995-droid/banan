import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsInt,
  IsOptional,
  IsPositive,
  IsString,
  MaxLength,
  Min,
  MinLength,
  NotEquals,
} from 'class-validator';
import { CouponType } from '@prisma/client';

export class NotifyCustomerDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  title!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  body!: string;
}

export class BroadcastDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  title!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  body!: string;

  /** Optional staff tag (vd "VIP"): only customers carrying it receive. */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  tag?: string;
}

export class AdjustPointsDto {
  @IsInt()
  @NotEquals(0)
  delta!: number;

  @IsString()
  @MinLength(1)
  @MaxLength(200)
  reason!: string;
}

export class UpdateNotesDto {
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  notes?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  tags?: string[];
}

export class IssueCouponDto {
  @IsEnum(CouponType)
  type!: CouponType;

  @IsInt()
  @IsPositive()
  value!: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  minSubtotalVnd?: number;

  @IsInt()
  @IsPositive()
  @Min(1)
  days!: number;
}

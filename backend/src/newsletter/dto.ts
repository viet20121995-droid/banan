import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsEmail,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class SubscribeDto {
  @IsEmail()
  @MaxLength(160)
  email!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  fullName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  source?: string;
}

export class ListSubscribersDto {
  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @Transform(({ value }) => value === 'true')
  confirmed?: boolean;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  perPage?: number;
}

/// Compose + send a newsletter campaign by email (+ optional in-app).
export class SendCampaignDto {
  @IsString()
  @MinLength(1)
  @MaxLength(160)
  subject!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  body!: string;

  /// Who to send to: confirmed newsletter subscribers, all opted-in
  /// customers, or both (deduped by email).
  @IsIn(['subscribers', 'customers', 'both'])
  audience!: 'subscribers' | 'customers' | 'both';

  /// Also push the same message as an in-app + FCM broadcast.
  @IsOptional()
  @IsBoolean()
  alsoInApp?: boolean;
}

import { IsBoolean, IsObject, IsOptional } from 'class-validator';

/// Partial update — admin sends only the program(s) they changed. Config
/// objects are free-form (shape validated/normalised on the client + by the
/// defaults merge); we only enforce they're objects here.
export class UpdateMarketingDto {
  @IsOptional() @IsBoolean() referralEnabled?: boolean;
  @IsOptional() @IsObject() referralConfig?: Record<string, unknown>;

  @IsOptional() @IsBoolean() giftCardEnabled?: boolean;
  @IsOptional() @IsObject() giftCardConfig?: Record<string, unknown>;

  @IsOptional() @IsBoolean() subscriptionEnabled?: boolean;
  @IsOptional() @IsObject() subscriptionConfig?: Record<string, unknown>;

  @IsOptional() @IsBoolean() cateringEnabled?: boolean;
  @IsOptional() @IsObject() cateringConfig?: Record<string, unknown>;

  @IsOptional() @IsBoolean() rewardsEnabled?: boolean;
  @IsOptional() @IsObject() rewardsConfig?: Record<string, unknown>;
}

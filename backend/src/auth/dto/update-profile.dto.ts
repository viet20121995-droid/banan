import { Gender } from '@prisma/client';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
  MinLength,
} from 'class-validator';

/** Self-service profile edits for the signed-in customer. Email and role
 *  are intentionally not editable here. All fields optional — only the
 *  provided ones are changed. */
export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  fullName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  phone?: string;

  @IsOptional()
  @IsDateString()
  birthday?: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @IsOptional()
  // Must be an http(s) URL (avatars are produced by the upload endpoint, which
  // returns an absolute https URL) — rejects javascript:/data: and other
  // schemes outright. require_tld:false keeps the api.<domain> / localhost dev
  // hosts valid.
  @IsUrl({ require_tld: false, require_protocol: true, protocols: ['http', 'https'] })
  @MaxLength(500)
  avatarUrl?: string;

  /// Notification preferences (opt-out).
  @IsOptional()
  @IsBoolean()
  marketingOptIn?: boolean;

  @IsOptional()
  @IsBoolean()
  orderUpdatesOptIn?: boolean;
}

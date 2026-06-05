import { IsString, MaxLength, MinLength } from 'class-validator';

export class ResetPasswordDto {
  /** Opaque token from the email link. */
  @IsString()
  @MinLength(10)
  token!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  newPassword!: string;
}

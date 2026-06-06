import { IsEmail, IsString, MaxLength, MinLength } from 'class-validator';

/** Request an email change — verified via a link sent to the new address. */
export class ChangeEmailDto {
  @IsEmail()
  @MaxLength(160)
  newEmail!: string;

  @IsString()
  @MinLength(1)
  password!: string;
}

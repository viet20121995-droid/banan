import { IsString, MinLength } from 'class-validator';

export class LoginDto {
  /** Email or phone — service resolves which. */
  @IsString()
  @MinLength(3)
  emailOrPhone!: string;

  @IsString()
  @MinLength(1)
  password!: string;
}

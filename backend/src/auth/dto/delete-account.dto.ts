import { IsString, MinLength } from 'class-validator';

/** Self-service account deletion — requires the current password. */
export class DeleteAccountDto {
  @IsString()
  @MinLength(1)
  password!: string;
}

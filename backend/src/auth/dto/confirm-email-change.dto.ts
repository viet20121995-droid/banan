import { IsString, MinLength } from 'class-validator';

export class ConfirmEmailChangeDto {
  @IsString()
  @MinLength(1)
  token!: string;
}

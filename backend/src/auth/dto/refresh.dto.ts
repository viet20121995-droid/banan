import { IsOptional, IsString, MinLength } from 'class-validator';

export class RefreshDto {
  @IsString()
  @MinLength(10)
  refreshToken!: string;

  @IsOptional()
  @IsString()
  deviceId?: string;
}

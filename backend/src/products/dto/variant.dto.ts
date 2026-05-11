import { IsBoolean, IsInt, IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class VariantInputDto {
  /** Present on existing variants we want to keep/update; absent on new rows. */
  @IsOptional()
  @IsUUID()
  id?: string;

  @IsString()
  size!: string;

  @IsString()
  flavor!: string;

  @IsOptional()
  @IsNumber()
  priceDelta?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  stockQty?: number;

  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;
}

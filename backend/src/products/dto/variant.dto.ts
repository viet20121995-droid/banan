import {
  IsBoolean,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

export class VariantInputDto {
  /** Present on existing variants we want to keep/update; absent on new rows. */
  @IsOptional()
  @IsUUID()
  id?: string;

  @IsString()
  size!: string;

  @IsString()
  flavor!: string;

  /**
   * Unified SKU, same value as the MES MfgProduct.code for this item
   * (e.g. VT00708). Empty/null clears it. Legacy codes may contain spaces.
   */
  @IsOptional()
  @Matches(/^[A-Za-z0-9][A-Za-z0-9 _-]*$/, {
    message: 'SKU chỉ gồm chữ, số, gạch ngang.',
  })
  @MaxLength(30)
  sku?: string | null;

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

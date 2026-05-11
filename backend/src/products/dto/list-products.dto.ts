import { Transform } from 'class-transformer';
import { IsBooleanString, IsInt, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';

export class ListProductsDto {
  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @IsOptional()
  @IsUUID()
  storeId?: string;

  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @IsBooleanString()
  seasonal?: string;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(50)
  perPage?: number;
}

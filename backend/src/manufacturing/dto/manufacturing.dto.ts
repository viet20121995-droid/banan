import { IsNumber, IsOptional, IsString, IsUUID, MaxLength, Min } from 'class-validator';

export class CreateMoDto {
  @IsUUID()
  bomId!: string;

  @IsNumber()
  @Min(0.001)
  qtyToProduce!: number;

  @IsOptional()
  @IsString()
  scheduledDate?: string;

  @IsOptional()
  @IsUUID()
  responsibleId?: string;
}

export class ProduceDto {
  @IsOptional()
  @IsNumber()
  @Min(0.001)
  producedQty?: number;
}

export class ReceiveDto {
  @IsUUID()
  productId!: string;

  @IsNumber()
  @Min(0.001)
  qty!: number;

  @IsUUID()
  uomId!: string;

  @IsNumber()
  @Min(0)
  unitCost!: number;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  lotName?: string;
}

export class ScrapDto {
  @IsUUID()
  productId!: string;

  @IsNumber()
  @Min(0.001)
  qty!: number;

  @IsUUID()
  uomId!: string;

  @IsString()
  @MaxLength(200)
  reason!: string;

  @IsOptional()
  @IsUUID()
  lotId?: string;

  @IsOptional()
  @IsUUID()
  moId?: string;
}

export class ExpiringQueryDto {
  @IsString()
  before!: string;
}

export class OnHandQueryDto {
  @IsOptional()
  @IsUUID()
  productId?: string;
}

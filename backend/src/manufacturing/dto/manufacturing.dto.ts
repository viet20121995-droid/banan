import {
  IsDateString,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateMoDto {
  @IsUUID()
  bomId!: string;

  @IsNumber()
  @Min(0.001)
  qtyToProduce!: number;

  @IsOptional()
  @IsDateString()
  scheduledDate?: string;

  @IsOptional()
  @IsUUID()
  responsibleId?: string;
}

export class ReceiveDto {
  @IsUUID()
  productId!: string;

  @IsNumber()
  @Min(0.001)
  qty!: number;

  // Optional — defaults to the product's own base UoM (so the app can post a
  // quantity in the product's unit without a UoM picker).
  @IsOptional()
  @IsUUID()
  uomId?: string;

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

  // Optional — defaults to the product's own base UoM.
  @IsOptional()
  @IsUUID()
  uomId?: string;

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

export class CreateQualityPointDto {
  @IsString()
  @MaxLength(120)
  titleVi!: string;

  @IsString()
  @MaxLength(120)
  titleEn!: string;

  @IsIn(['MEASURE', 'PASS_FAIL'])
  testType!: 'MEASURE' | 'PASS_FAIL';

  @IsOptional()
  @IsUUID()
  bomOperationId?: string;

  @IsOptional()
  @IsUUID()
  productId?: string;

  @IsOptional()
  @IsNumber()
  normMin?: number;

  @IsOptional()
  @IsNumber()
  normMax?: number;

  @IsOptional()
  @IsString()
  @MaxLength(16)
  unit?: string;
}

export class RecordCheckDto {
  @IsUUID()
  qualityPointId!: string;

  @IsUUID()
  workOrderId!: string;

  @IsOptional()
  @IsNumber()
  measuredValue?: number;

  @IsOptional()
  @IsIn(['PASS', 'FAIL'])
  passFail?: 'PASS' | 'FAIL';

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}

export class SetAlertStageDto {
  @IsIn(['NEW', 'CONFIRMED', 'SOLVED'])
  stage!: 'NEW' | 'CONFIRMED' | 'SOLVED';
}

/**
 * Plan a manufacturing order: set/clear its scheduled date and responsible
 * person. Both fields are optional; passing an explicit `null` clears the
 * field, omitting it leaves the current value untouched.
 */
export class PlanMoDto {
  @IsOptional()
  @IsDateString()
  scheduledDate?: string | null;

  @IsOptional()
  @IsUUID()
  responsibleId?: string | null;
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

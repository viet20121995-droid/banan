import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';

/**
 * A BoM line / operation as posted by the editor. Contents are validated in the
 * service (component/work-center existence, qty > 0) — matching the module's
 * "validate deeply in the service" style rather than nested class-validator.
 */
export interface BomLineInput {
  componentId: string;
  qty: number;
  uomId: string;
}

export interface BomOperationInput {
  nameVi: string;
  nameEn?: string;
  workCenterId: string;
  durationMinutes: number;
}

export class CreateBomDto {
  @IsUUID()
  productId!: string;

  @IsNumber()
  @Min(0.001)
  outputQty!: number;

  @IsUUID()
  uomId!: string;

  @IsArray()
  lines!: BomLineInput[];

  @IsOptional()
  @IsArray()
  operations?: BomOperationInput[];
}

export class CreateProductDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  code!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  nameVi!: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  nameEn?: string;

  @IsUUID()
  categoryId!: string;

  @IsUUID()
  uomId!: string;

  @IsIn(['RAW', 'SEMI', 'FINISHED', 'PACKAGING'])
  type!: 'RAW' | 'SEMI' | 'FINISHED' | 'PACKAGING';

  @IsOptional()
  @IsIn(['NONE', 'LOT'])
  tracking?: 'NONE' | 'LOT';

  @IsOptional()
  @IsBoolean()
  useExpiration?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  expirationDays?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  standardCost?: number;
}

/** Partial update — every field optional; `active: false` archives the product. */
export class UpdateProductDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  code?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  nameVi?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  nameEn?: string;

  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @IsOptional()
  @IsUUID()
  uomId?: string;

  @IsOptional()
  @IsIn(['RAW', 'SEMI', 'FINISHED', 'PACKAGING'])
  type?: 'RAW' | 'SEMI' | 'FINISHED' | 'PACKAGING';

  @IsOptional()
  @IsIn(['NONE', 'LOT'])
  tracking?: 'NONE' | 'LOT';

  @IsOptional()
  @IsBoolean()
  useExpiration?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  expirationDays?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  standardCost?: number;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}

export class CreateMaintenanceDto {
  @IsUUID()
  workCenterId!: string;

  @IsOptional()
  @IsIn(['PREVENTIVE', 'CORRECTIVE'])
  type?: 'PREVENTIVE' | 'CORRECTIVE';

  @IsDateString()
  scheduledDate!: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}

export class CompleteMaintenanceDto {
  @IsOptional()
  @IsNumber()
  @Min(0)
  downtimeMin?: number;
}

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

  /** Books this receipt against a purchase-order line (updates qtyReceived + PO state). */
  @IsOptional()
  @IsUUID()
  poLineId?: string;
}

export class CreateSupplierDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  address?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}

/** Partial update — every field optional; `active: false` archives the supplier. */
export class UpdateSupplierDto {
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  address?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}

/**
 * A PO line as posted by the editor. Quantities are in the product's own base
 * UoM (same convention as ReceiveDto's default). Deep-validated in the service.
 */
export interface PoLineInput {
  productId: string;
  qty: number;
  unitPrice: number;
}

export class CreatePoDto {
  @IsUUID()
  supplierId!: string;

  @IsOptional()
  @IsDateString()
  expectedDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;

  @IsArray()
  lines!: PoLineInput[];
}

/** Draft-only edit; supplying `lines` replaces the whole line list. */
export class UpdatePoDto {
  @IsOptional()
  @IsUUID()
  supplierId?: string;

  @IsOptional()
  @IsDateString()
  expectedDate?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;

  @IsOptional()
  @IsArray()
  lines?: PoLineInput[];
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

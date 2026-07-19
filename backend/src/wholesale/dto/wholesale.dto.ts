import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEmail,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class CreateWholesaleAccountDto {
  @IsUUID()
  userId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  companyName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  contactName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  contactPhone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  taxId?: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(160)
  billingEmail?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  deliveryAddress!: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  creditLimitVnd?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(365)
  paymentTermDays?: number;
}

export class UpdateWholesaleAccountDto {
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  companyName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  contactName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  contactPhone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  taxId?: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(160)
  billingEmail?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  deliveryAddress?: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  creditLimitVnd?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(365)
  paymentTermDays?: number;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  blockedReason?: string;
}

export class CreateContractDto {
  @IsUUID()
  wholesaleAccountId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  name!: string;

  @IsDateString()
  startsAt!: string;

  @IsOptional()
  @IsDateString()
  endsAt?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  minOrderVnd?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  defaultDiscountPct?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(365)
  paymentTermDays?: number;
}

export class UpdateContractDto {
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  name?: string;

  @IsOptional()
  @IsDateString()
  startsAt?: string;

  @IsOptional()
  @IsDateString()
  endsAt?: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  minOrderVnd?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  defaultDiscountPct?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(365)
  paymentTermDays?: number;
}

export class ContractLineDto {
  @IsUUID()
  productId!: string;

  @IsOptional()
  @IsUUID()
  variantId?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  fixedPriceVnd?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  discountPct?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  minQty?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  leadTimeHours?: number;
}

export class UpdateContractLineDto {
  @IsOptional()
  @IsInt()
  @Min(0)
  fixedPriceVnd?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  discountPct?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  minQty?: number;

  @IsOptional()
  @IsBoolean()
  active?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  leadTimeHours?: number;
}

export class WholesaleOrderItemDto {
  @IsUUID()
  productId!: string;

  @IsOptional()
  @IsUUID()
  variantId?: string;

  @IsInt()
  @Min(1)
  quantity!: number;
}

export class CreateWholesaleOrderDto {
  @IsUUID()
  contractId!: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(60)
  @ValidateNested({ each: true })
  @Type(() => WholesaleOrderItemDto)
  items!: WholesaleOrderItemDto[];

  @IsOptional()
  @IsDateString()
  scheduledFor?: string;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  notes?: string;

  /** Buyer's own PO code — snapshot onto the order for their reconciliation. */
  @IsOptional()
  @IsString()
  @MaxLength(60)
  poCode?: string;

  /** Dedup key: a retried POST with the same key returns the first order. */
  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(64)
  clientRequestId?: string;
}

/** One confirmed collection against a receivable. */
export class RecordWholesalePaymentDto {
  /** Omit to settle the full remaining balance. */
  @IsOptional()
  @IsInt()
  @Min(1)
  amountVnd?: number;

  @IsOptional()
  @IsIn(['CASH', 'BANK_TRANSFER', 'CARD', 'OTHER'])
  method?: 'CASH' | 'BANK_TRANSFER' | 'CARD' | 'OTHER';

  /** Bank transaction reference for reconciliation. */
  @IsOptional()
  @IsString()
  @MaxLength(80)
  reference?: string;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  note?: string;
}

export class RejectWholesaleOrderDto {
  @IsOptional()
  @IsString()
  @MaxLength(280)
  reason?: string;
}

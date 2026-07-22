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
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

import { OrderItemInputDto } from './create-order.dto';

/**
 * Staff keys in an order for a walk-in customer at the shop counter.
 * Settlement is the till (paid or to-collect) — never an online gateway.
 */
export class CounterOrderDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(40)
  @ValidateNested({ each: true })
  @Type(() => OrderItemInputDto)
  items!: OrderItemInputDto[];

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  customerName!: string;

  @IsString()
  @MinLength(7)
  @MaxLength(20)
  customerPhone!: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(160)
  customerEmail?: string;

  @IsOptional()
  @IsDateString()
  scheduledFor?: string;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  notes?: string;

  /** Did the customer already pay at the till? */
  @IsIn(['PAID_AT_COUNTER', 'UNPAID_AT_COUNTER'])
  payment!: 'PAID_AT_COUNTER' | 'UNPAID_AT_COUNTER';

  /** Push straight onto the kitchen board. Default true. */
  @IsOptional()
  @IsBoolean()
  sendToKitchen?: boolean;

  /** ADMIN only — which store the order belongs to (staff use their own). */
  @IsOptional()
  @IsUUID()
  storeId?: string;

  /** Dedup key: a retried POST with the same key returns the first order. */
  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(64)
  clientRequestId?: string;
}

/** One kitchen-warehouse (MES) line: supplies that are not menu products. */
export class TransferMfgItemDto {
  @IsUUID()
  mfgProductId!: string;

  /** In the MES product's base UoM. */
  @IsNumber()
  @Min(0.001)
  qty!: number;
}

/**
 * A branch orders goods from the kitchen for itself (restock / display case).
 * Internal — no customer, no payment, excluded from retail revenue.
 * At least one of [items] (menu products) or [mfgItems] (supplies) must be
 * non-empty — enforced in the service.
 */
export class InternalTransferDto {
  @IsArray()
  @ArrayMaxSize(40)
  @ValidateNested({ each: true })
  @Type(() => OrderItemInputDto)
  items!: OrderItemInputDto[];

  /** Kitchen-warehouse supplies (milk, fruit, cups…) to deliver to the branch. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(40)
  @ValidateNested({ each: true })
  @Type(() => TransferMfgItemDto)
  mfgItems?: TransferMfgItemDto[];

  /** When the branch needs the goods. */
  @IsOptional()
  @IsDateString()
  scheduledFor?: string;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  notes?: string;

  /** ADMIN only — request on behalf of this store (owner uses their own). */
  @IsOptional()
  @IsUUID()
  requestingStoreId?: string;

  /** Receiving branch; defaults to the requesting store. */
  @IsOptional()
  @IsUUID()
  destinationStoreId?: string;

  /** Push straight onto the kitchen board. Default true. */
  @IsOptional()
  @IsBoolean()
  sendToKitchen?: boolean;

  /** Dedup key: a retried POST with the same key returns the first order. */
  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(64)
  clientRequestId?: string;
}

/** One received line: how many of an order item actually arrived. */
export class ReceivedItemDto {
  @IsUUID()
  orderItemId!: string;

  @IsInt()
  @Min(0)
  receivedQty!: number;
}

/** One received MES line: how much of a supply item actually arrived. */
export class ReceivedMfgItemDto {
  @IsUUID()
  itemId!: string;

  @IsNumber()
  @Min(0)
  receivedQty!: number;
}

/** Destination branch signs for an internal transfer (→ COMPLETED). */
export class ReceiveTransferDto {
  @IsOptional()
  @IsString()
  @MaxLength(280)
  note?: string;

  /** Omit for a full receipt; include lines to report shortages/damage. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(40)
  @ValidateNested({ each: true })
  @Type(() => ReceivedItemDto)
  items?: ReceivedItemDto[];

  /** Same, for the kitchen-warehouse (MES) lines. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(40)
  @ValidateNested({ each: true })
  @Type(() => ReceivedMfgItemDto)
  mfgItems?: ReceivedMfgItemDto[];
}

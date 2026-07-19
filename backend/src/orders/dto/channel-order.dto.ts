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

/**
 * A branch orders goods from the kitchen for itself (restock / display case).
 * Internal — no customer, no payment, excluded from retail revenue.
 */
export class InternalTransferDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(40)
  @ValidateNested({ each: true })
  @Type(() => OrderItemInputDto)
  items!: OrderItemInputDto[];

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
}

import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { PaymentProvider } from '@prisma/client';

export class OrderItemInputDto {
  @IsUUID()
  productId!: string;

  @IsOptional()
  @IsUUID()
  variantId?: string;

  @IsInt()
  @Min(1)
  quantity!: number;

  @IsOptional()
  @IsString()
  @MaxLength(140)
  customMessage?: string;
}

export class OrderAddressInputDto {
  @IsString()
  @MaxLength(120)
  recipient!: string;

  @IsString()
  @MaxLength(20)
  phone!: string;

  @IsString()
  @MaxLength(160)
  line1!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  line2?: string;

  @IsString()
  @MaxLength(80)
  city!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  district?: string;
}

export type FulfillmentTypeWire = 'PICKUP' | 'DELIVERY';

export class CreateOrderDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(40)
  @ValidateNested({ each: true })
  @Type(() => OrderItemInputDto)
  items!: OrderItemInputDto[];

  @IsEnum(['PICKUP', 'DELIVERY'])
  fulfillmentType!: FulfillmentTypeWire;

  @IsEnum(PaymentProvider)
  paymentMethod!: PaymentProvider;

  @IsOptional()
  @ValidateNested()
  @Type(() => OrderAddressInputDto)
  address?: OrderAddressInputDto;

  @IsOptional()
  @IsDateString()
  scheduledFor?: string;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  notes?: string;

  /** Optional coupon code — case-insensitive. Validated server-side. */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  couponCode?: string;

  /** Number of loyalty points to redeem against this order. */
  @IsOptional()
  @IsInt()
  @Min(0)
  pointsToRedeem?: number;
}

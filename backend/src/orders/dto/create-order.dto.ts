import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEmail,
  IsEnum,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
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

  /// Cake personalization payload — only meaningful for items in the
  /// birthday-cake collection. Free-form object; the customer app builds
  /// it via the wizard. See `OrderItem.personalization` doc-comment in
  /// the Prisma schema for the canonical shape.
  @IsOptional()
  @IsObject()
  personalization?: Record<string, unknown>;
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

  /// Pre-reform district hint, kept for legacy / out-of-HCMC addresses.
  @IsOptional()
  @IsString()
  @MaxLength(80)
  district?: string;

  /// HCMC post-2025 ward code from `GET /geo/hcm-wards`. Required for
  /// HCMC delivery addresses — drives distance-based surcharge.
  @IsOptional()
  @IsString()
  @MaxLength(60)
  wardCode?: string;
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

  /**
   * For PICKUP orders — which branch the customer wants to collect from.
   * Overrides the product's home store as the fulfilling store, so the
   * merchant at the chosen branch sees the order in their queue.
   */
  @IsOptional()
  @IsUUID()
  pickupStoreId?: string;

  /**
   * For DELIVERY orders — which branch fulfills (and ships from). Lets a
   * customer pick the nearest open branch instead of always routing to the
   * catalog store. Optional: when omitted we fall back to the catalog store
   * the products belong to.
   */
  @IsOptional()
  @IsUUID()
  deliveryStoreId?: string;

  @IsOptional()
  @IsDateString()
  scheduledFor?: string;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  notes?: string;

  // ── Gift order ("tặng quà khi đặt hàng") ─────────────────────────────────

  @IsOptional()
  @IsBoolean()
  isGift?: boolean;

  /** Greeting-card message included with the gift. */
  @IsOptional()
  @IsString()
  @MaxLength(280)
  giftMessage?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  giftRecipientName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  giftRecipientPhone?: string;

  /** Add gift wrapping / a gift box. */
  @IsOptional()
  @IsBoolean()
  giftWrap?: boolean;

  /** Hide prices on the printed slip the recipient sees. */
  @IsOptional()
  @IsBoolean()
  hidePrice?: boolean;

  /** Optional coupon code — case-insensitive. Validated server-side. */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  couponCode?: string;

  /** Optional gift-card code — redeemed (balance-based) against the total. */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  giftCardCode?: string;

  /** Number of loyalty points to redeem against this order. */
  @IsOptional()
  @IsInt()
  @Min(0)
  pointsToRedeem?: number;

  // ── Guest checkout ────────────────────────────────────────────────────
  // Optional — only used when the request has no auth token. The service
  // upserts a CUSTOMER user keyed by phone (or creates a new one), then
  // creates the order under that user's id.

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  guestFullName?: string;

  @IsOptional()
  @IsString()
  @MinLength(7)
  @MaxLength(20)
  guestPhone?: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(160)
  guestEmail?: string;

  // ── VAT invoice (hóa đơn đỏ) ─────────────────────────────────────────
  // Optional — toggled at checkout. When `requestVatInvoice` is true the
  // 4 company fields below become required (enforced in the service).

  @IsOptional()
  @IsBoolean()
  requestVatInvoice?: boolean;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  invoiceCompanyName?: string;

  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(20)
  invoiceTaxId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  invoiceAddress?: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(160)
  invoiceEmail?: string;
}

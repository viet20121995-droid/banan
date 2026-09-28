import { IsISO8601, IsOptional, IsString, MaxLength, MinLength, ValidateIf } from 'class-validator';

/// Admin hand-fix of an order: move the scheduled slot (null = "làm ngay")
/// or correct the customer's typo'd name. Every change is written to the
/// order's history.
export class AdminEditOrderDto {
  /** ISO instant; null clears the slot. Omit to leave unchanged. */
  @ValidateIf((_, v) => v !== undefined && v !== null)
  @IsISO8601()
  scheduledFor?: string | null;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  customerName?: string;

  /** Delivery address fixes (text only — the ward and fee stay as quoted). */
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  recipient?: string;

  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(20)
  recipientPhone?: string;

  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(300)
  addressLine?: string;
}

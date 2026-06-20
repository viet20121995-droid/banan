import { IsEmail, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/// Merchant-side customer creation — typically used when a phone customer
/// places an order and the merchant wants a record. Phone is the primary
/// key (matches the guest-checkout upsert lookup elsewhere) so we can find
/// the same customer next time they call.
export class CreateCustomerDto {
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  fullName!: string;

  @IsString()
  @MinLength(7)
  @MaxLength(20)
  phone!: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(160)
  email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  notes?: string;
}

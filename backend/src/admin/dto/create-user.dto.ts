import {
  IsEmail,
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

/** Roles an admin may provision through the console. ADMIN is intentionally
 *  excluded — super-users are created out-of-band (seed) to avoid an
 *  in-app privilege-escalation path. */
export enum ProvisionableRole {
  CUSTOMER = 'CUSTOMER',
  MERCHANT_OWNER = 'MERCHANT_OWNER',
  MERCHANT_STAFF = 'MERCHANT_STAFF',
  KITCHEN_MANAGER = 'KITCHEN_MANAGER',
  KITCHEN_STAFF = 'KITCHEN_STAFF',
}

export class CreateUserDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  fullName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  phone?: string;

  @IsEnum(ProvisionableRole)
  role!: ProvisionableRole;

  /** Required for MERCHANT_* roles; ignored otherwise. */
  @IsOptional()
  @IsUUID()
  storeId?: string;

  /** Required for KITCHEN_* roles; ignored otherwise. */
  @IsOptional()
  @IsUUID()
  kitchenId?: string;
}

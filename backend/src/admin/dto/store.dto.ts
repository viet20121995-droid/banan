import { IsNumber, IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

/** Create a new branch (chain store). Operational fields (opening hours, pause
 *  flags, min-order, lead time) are tuned afterwards via the merchant settings
 *  screen — this only captures the branch's identity. `openingHours` is seeded
 *  to a sensible default server-side. */
export class CreateStoreDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  slug!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(255)
  address!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(40)
  phone!: string;

  /** HCMC ward slug (drives same-ward / other-ward delivery fee). */
  @IsOptional()
  @IsString()
  @MaxLength(80)
  wardCode?: string;

  /** Kitchen that fulfils this branch's orders by default. */
  @IsOptional()
  @IsUUID()
  defaultKitchenId?: string;

  @IsOptional()
  @IsNumber()
  lat?: number;

  @IsOptional()
  @IsNumber()
  lng?: number;
}

/** Edit a branch's identity. Every field optional; send `null` for
 *  `defaultKitchenId` to detach the default kitchen. */
export class UpdateStoreDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  slug?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  address?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(40)
  phone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  wardCode?: string;

  @IsOptional()
  @IsUUID()
  defaultKitchenId?: string | null;

  @IsOptional()
  @IsNumber()
  lat?: number;

  @IsOptional()
  @IsNumber()
  lng?: number;
}

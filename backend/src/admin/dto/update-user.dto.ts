import {
  IsBoolean,
  IsEmail,
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

import { ProvisionableRole } from './create-user.dto';

/** Admin edit of an existing user. All fields optional — only supplied
 *  fields change. ADMIN role is not assignable (no privilege escalation). */
export class UpdateUserDto {
  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  fullName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  phone?: string;

  @IsOptional()
  @IsEnum(ProvisionableRole)
  role?: ProvisionableRole;

  @IsOptional()
  @IsUUID()
  storeId?: string;

  @IsOptional()
  @IsUUID()
  kitchenId?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

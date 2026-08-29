import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsIn,
  IsISO8601,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

const CATEGORIES = ['PHA_CHE', 'CHE_BIEN', 'ATVSTP', 'QUY_DINH', 'DICH_VU_KHACH_HANG'] as const;
const KINDS = ['FILE', 'VIDEO', 'LINK'] as const;

export class CreatePersonDto {
  @IsString()
  @MaxLength(200)
  fullName!: string;

  @IsUUID()
  storeId!: string;

  @IsString()
  @MaxLength(100)
  position!: string;

  @IsOptional()
  @IsISO8601()
  startDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}

export class UpdatePersonDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  fullName?: string;

  /** Changing store appends a transfer-history row. */
  @IsOptional()
  @IsUUID()
  storeId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  position?: string;

  @IsOptional()
  @IsISO8601()
  startDate?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}

export class CreateMaterialDto {
  @IsString()
  @MaxLength(300)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsIn(CATEGORIES as unknown as string[])
  category!: (typeof CATEGORIES)[number];

  @IsIn(KINDS as unknown as string[])
  kind!: (typeof KINDS)[number];

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  url?: string;

  @IsOptional()
  @IsBoolean()
  isRequired?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  estimatedMinutes?: number;

  @IsOptional()
  @IsISO8601()
  effectiveFrom?: string;
}

export class UpdateMaterialDto {
  @IsOptional()
  @IsString()
  @MaxLength(300)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsBoolean()
  isRequired?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  estimatedMinutes?: number;
}

export class PathItemDto {
  @IsUUID()
  materialId!: string;

  @IsOptional()
  @IsBoolean()
  isRequired?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  dueDays?: number;
}

export class CreatePathDto {
  @IsString()
  @MaxLength(200)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  position?: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PathItemDto)
  items!: PathItemDto[];
}

export class UpdatePathDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  position?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PathItemDto)
  items?: PathItemDto[];
}

export class AssignPathDto {
  @IsUUID()
  personId!: string;

  @IsUUID()
  pathId!: string;

  @IsISO8601()
  startDate!: string;
}

export class UpdateProgressDto {
  @IsOptional()
  @IsIn(['NOT_STARTED', 'IN_PROGRESS', 'PENDING_CONFIRMATION', 'COMPLETED'])
  status?: 'NOT_STARTED' | 'IN_PROGRESS' | 'PENDING_CONFIRMATION' | 'COMPLETED';

  @IsOptional()
  @IsInt()
  @Min(0)
  quizScore?: number;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}

export class PeopleQueryDto {
  @IsOptional()
  @IsUUID()
  storeId?: string;

  @IsOptional()
  @IsIn(['true', 'false'])
  active?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  position?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  q?: string;
}

export class ProgressQueryDto {
  @IsOptional()
  @IsUUID()
  storeId?: string;

  @IsOptional()
  @IsUUID()
  personId?: string;

  @IsOptional()
  @IsIn(['NOT_STARTED', 'IN_PROGRESS', 'PENDING_CONFIRMATION', 'COMPLETED', 'EXPIRED'])
  status?: string;

  @IsOptional()
  @IsIn(['true'])
  overdue?: string;
}

/** Trainee self-service: own progress only, status only — quiz scores and
 *  notes stay admin-recorded. */
export class UpdateOwnProgressDto {
  @IsIn(['IN_PROGRESS', 'COMPLETED'])
  status!: 'IN_PROGRESS' | 'COMPLETED';
}

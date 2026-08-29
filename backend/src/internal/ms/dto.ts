import { Type } from 'class-transformer';
import {
  IsArray,
  IsIn,
  IsISO8601,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class CreateMsAssignmentDto {
  @IsUUID()
  storeId!: string;

  @IsOptional()
  @IsISO8601()
  windowStart?: string;

  @IsOptional()
  @IsISO8601()
  windowEnd?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  scenario?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  productsToBuy?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  budgetVnd?: number;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  brief?: string;

  @IsOptional()
  @IsISO8601()
  deadline?: string;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  internalNotes?: string;
}

export class UpdateMsAssignmentDto extends CreateMsAssignmentDto {
  @IsOptional()
  @IsUUID()
  declare storeId: string;
}

import { PaginationDto } from '../../common/dto/pagination.dto';

// One @Query() DTO per route (forbidNonWhitelisted validates the whole
// query object) — pagination is inherited, not a second decorator.
export class MsListQueryDto extends PaginationDto {
  @IsOptional()
  @IsUUID()
  storeId?: string;

  @IsOptional()
  @IsIn(['ADMIN', 'EMPLOYEE_SELF_SERVICE'])
  source?: string;

  @IsOptional()
  @IsIn([
    'DRAFT',
    'ASSIGNED',
    'OPENED',
    'SUBMITTED',
    'NEEDS_REVISION',
    'APPROVED',
    'REVOKED',
    'EXPIRED',
  ])
  status?: string;

  @IsOptional()
  @IsIn(['PASS', 'CRITICAL_FAIL'])
  outcome?: string;

  @IsOptional()
  @IsISO8601()
  from?: string;

  @IsOptional()
  @IsISO8601()
  to?: string;
}

export class IssueTokenDto {
  /** Token lifetime in days (default 14, max 60). */
  @IsOptional()
  @IsInt()
  @Min(1)
  ttlDays?: number;
}

export class RequestRevisionDto {
  @IsString()
  @Matches(/\S/, { message: 'note không được để trống' })
  @MaxLength(2000)
  note!: string;
}

// ── public (token in BODY — URLs are logged, bodies are not) ────────────────

/**
 * Public MS link generator. Deliberately tiny: NO templateId, NO status, NO
 * report/recipient fields — the server chooses everything sensitive
 * (forbidNonWhitelisted rejects any extra key outright).
 */
export class SelfServiceCreateDto {
  /** \S: whitespace-only names would erase the audit trail after trim(). */
  @IsString()
  @Matches(/\S/, { message: 'requesterName không được để trống' })
  @MaxLength(200)
  requesterName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  employeeCode?: string;

  /** Shared internal access code — compared server-side, never stored. */
  @IsString()
  @Matches(/\S/, { message: 'accessCode không được để trống' })
  @MaxLength(200)
  accessCode!: string;

  @IsUUID()
  storeId!: string;

  /** Link lifetime; server clamps to 1–7 days (default 7). */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(7)
  ttlDays?: number;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;

  /** Client-generated per-submission key — double-click safe. */
  @IsString()
  @Matches(/^[\w-]{16,64}$/)
  idempotencyKey!: string;
}

export class PublicTokenDto {
  @IsString()
  @Matches(/^[\w-]{20,100}$/)
  token!: string;
}

class PublicAnswerDto {
  @IsUUID()
  questionId!: string;

  @IsOptional()
  @IsIn(['YES', 'NO', 'NOT_AVAILABLE'])
  value?: 'YES' | 'NO' | 'NOT_AVAILABLE' | null;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  note?: string;
}

export class PublicSaveDto extends PublicTokenDto {
  @IsOptional()
  @IsISO8601()
  enteredAt?: string;

  @IsOptional()
  @IsISO8601()
  greetedAt?: string;

  @IsOptional()
  @IsISO8601()
  orderStartAt?: string;

  @IsOptional()
  @IsISO8601()
  paidAt?: string;

  @IsOptional()
  @IsISO8601()
  receivedAt?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  productsBought?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  amountPaidVnd?: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  staffName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  overallComment?: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PublicAnswerDto)
  answers?: PublicAnswerDto[];
}

export class PublicRemoveEvidenceDto extends PublicTokenDto {
  @IsUUID()
  evidenceId!: string;
}

export class PublicFileDto extends PublicTokenDto {
  /** Private evidence file name (hex + extension). */
  @IsString()
  @Matches(/^[a-f0-9]{32}\.(jpg|png|webp)$/)
  name!: string;
}

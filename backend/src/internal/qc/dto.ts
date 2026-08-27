import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsISO8601,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateQcInspectionDto {
  @IsUUID()
  storeId!: string;

  /** Calendar day of the inspection, ISO date or datetime. */
  @IsISO8601()
  inspectionDate!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  inspectorName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  staffOnShift?: string;
}

export class UpdateQcInspectionDto {
  @IsOptional()
  @IsISO8601()
  inspectionDate?: string;

  @IsOptional()
  @IsISO8601()
  startedAt?: string;

  @IsOptional()
  @IsISO8601()
  endedAt?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  inspectorName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  staffOnShift?: string;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  generalNotes?: string;
}

export class UpsertQcAnswerDto {
  @IsIn(['PASS', 'FAIL', 'NOT_AVAILABLE'])
  value!: 'PASS' | 'FAIL' | 'NOT_AVAILABLE';

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  failDetail?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  naReason?: string;
}

export class UpsertQcRiskDto {
  @IsBoolean()
  occurred!: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  detail?: string;
}

export class AttachEvidenceDto {
  /** PRIVATE file name returned by POST /internal/files/upload — never a URL
   *  (evidence photos are not publicly served). */
  @IsString()
  @Matches(/^[a-f0-9]{32}\.(jpg|png|webp)$/)
  name!: string;

  @IsString()
  @Matches(/^image\/(jpeg|png|webp)$/)
  mimeType!: string;

  @IsInt()
  @Min(1)
  sizeBytes!: number;
}

import { PaginationDto } from '../../common/dto/pagination.dto';

// Extends pagination — the route takes ONE @Query() DTO because the global
// forbidNonWhitelisted pipe validates the whole query object against it.
export class QcListQueryDto extends PaginationDto {
  @IsOptional()
  @IsUUID()
  storeId?: string;

  @IsOptional()
  @IsIn(['DRAFT', 'IN_PROGRESS', 'COMPLETED'])
  status?: 'DRAFT' | 'IN_PROGRESS' | 'COMPLETED';

  @IsOptional()
  @IsIn(['PASS', 'FAIL', 'CRITICAL_FAIL'])
  outcome?: 'PASS' | 'FAIL' | 'CRITICAL_FAIL';

  @IsOptional()
  @IsISO8601()
  from?: string;

  @IsOptional()
  @IsISO8601()
  to?: string;
}

export class QcCompareQueryDto {
  @IsISO8601()
  from!: string;

  @IsISO8601()
  to!: string;
}

/** Shared by the QC and MS report.pdf endpoints: pick a specific approved
 *  revision; omitted = latest approved, or a watermarked draft preview. */
export class ReportPdfQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  revision?: number;
}

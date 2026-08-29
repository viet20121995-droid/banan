import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
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

import { PaginationDto } from '../../common/dto/pagination.dto';

export const SURVEY_QUESTION_TYPES = [
  'EMOJI_SCALE',
  'RATING',
  'NPS',
  'SINGLE_CHOICE',
  'MULTI_CHOICE',
  'TEXT',
  'YES_NO',
] as const;

// ── public submit ───────────────────────────────────────────────────────────

export class PublicSurveyAnswerDto {
  @IsUUID()
  questionId!: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10)
  numberValue?: number;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  textValue?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(50, { each: true })
  @ArrayMaxSize(20)
  optionValues?: string[];
}

export class PublicSurveyContactDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;

  /** Explicit consent to be contacted — PII is stored ONLY when true. */
  @IsOptional()
  @IsBoolean()
  consent?: boolean;
}

/**
 * Public survey submission. Deliberately narrow: no status/score/case/reward
 * fields — the server derives everything (forbidNonWhitelisted rejects any
 * extra key outright). No IP, no table, no tokens.
 */
export class PublicSurveySubmitDto {
  @IsUUID()
  templateId!: string;

  @IsUUID()
  storeId!: string;

  @IsOptional()
  @IsIn(['vi', 'en'])
  locale?: string;

  /** Client dedup key — a retried submit returns the SAME response/reward. */
  @IsString()
  @Matches(/^[\w-]{16,64}$/)
  clientRequestId!: string;

  /** Anonymous per-browser key for the reward daily cap. Optional — feedback
   *  without it is accepted; a reward is not issued without it.
   *  KNOWN LIMIT: client-chosen, so it only stops casual double-dipping;
   *  daily/total caps bound the abuse. Real anti-fraud (receipt code / phone
   *  OTP) is a prerequisite for turning real rewards on. */
  @IsOptional()
  @IsString()
  @Matches(/^[\w-]{8,64}$/)
  browserKey?: string;

  @IsArray()
  @ArrayMaxSize(60)
  @ValidateNested({ each: true })
  @Type(() => PublicSurveyAnswerDto)
  answers!: PublicSurveyAnswerDto[];

  @IsOptional()
  @ValidateNested()
  @Type(() => PublicSurveyContactDto)
  contact?: PublicSurveyContactDto;
}

// ── admin: reports ──────────────────────────────────────────────────────────

const CASE_STATUS_FILTERS = ['NEW', 'IN_PROGRESS', 'RESOLVED', 'OVERDUE'] as const;

export class SurveyReportQueryDto {
  /** Calendar days (`yyyy-MM-dd`), interpreted in Asia/Ho_Chi_Minh — never a
   *  datetime, so client/server timezones can't shift a day report by 7h.
   *  `to` is inclusive. */
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'from phải là yyyy-MM-dd' })
  from?: string;

  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'to phải là yyyy-MM-dd' })
  to?: string;

  @IsOptional()
  @IsUUID()
  storeId?: string;

  @IsOptional()
  @IsUUID()
  templateId?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  overall?: number;

  @IsOptional()
  @IsIn(CASE_STATUS_FILTERS)
  caseStatus?: string;

  @IsOptional()
  @IsIn(['day', 'week'])
  bucket?: string;
}

export class SurveyResponsesQueryDto extends SurveyReportQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  perPage?: number;
}

// ── admin: cases ────────────────────────────────────────────────────────────

export class SurveyCasesQueryDto extends PaginationDto {
  @IsOptional()
  @IsIn(CASE_STATUS_FILTERS)
  status?: string;

  @IsOptional()
  @IsUUID()
  storeId?: string;
}

export class UpdateSurveyCaseDto {
  @IsOptional()
  @IsIn(['NEW', 'IN_PROGRESS', 'RESOLVED'])
  status?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  assigneeName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  note?: string;
}

// ── admin: template editor ──────────────────────────────────────────────────

export class CreateSurveyTemplateDto {
  @IsOptional()
  @IsString()
  @Matches(/\S/, { message: 'name không được để trống' })
  @MaxLength(200)
  name?: string;

  /** Clone an existing version (any status) into a new DRAFT. */
  @IsOptional()
  @IsUUID()
  cloneFromId?: string;
}

export class UpdateSurveyTemplateDto {
  @IsString()
  @Matches(/\S/, { message: 'name không được để trống' })
  @MaxLength(200)
  name!: string;
}

export class SurveyOptionInputDto {
  @IsString()
  @Matches(/^[\w-]{1,50}$/)
  value!: string;

  @IsString()
  @Matches(/\S/)
  @MaxLength(200)
  labelVi!: string;

  @IsString()
  @Matches(/\S/)
  @MaxLength(200)
  labelEn!: string;
}

export class SurveyQuestionInputDto {
  @IsString()
  @Matches(/^[\w-]{1,50}$/)
  code!: string;

  @IsIn(SURVEY_QUESTION_TYPES)
  type!: string;

  @IsString()
  @Matches(/\S/)
  @MaxLength(500)
  textVi!: string;

  @IsString()
  @Matches(/\S/)
  @MaxLength(500)
  textEn!: string;

  @IsOptional()
  @IsBoolean()
  required?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(4000)
  maxLength?: number;

  @IsOptional()
  @IsString()
  @Matches(/^[\w-]{1,50}$/)
  showIfQuestionCode?: string;

  @IsOptional()
  @IsIn(['LTE', 'GTE', 'EQ'])
  showIfOp?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10)
  showIfValue?: number;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => SurveyOptionInputDto)
  options?: SurveyOptionInputDto[];
}

export class ReplaceSurveyQuestionsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(60)
  @ValidateNested({ each: true })
  @Type(() => SurveyQuestionInputDto)
  questions!: SurveyQuestionInputDto[];
}

// ── admin: rewards ──────────────────────────────────────────────────────────

/** Nullable optionals: `null` CLEARS the stored value, omitting keeps it. */
export class CreateSurveyRewardDto {
  @IsString()
  @Matches(/\S/, { message: 'name không được để trống' })
  @MaxLength(200)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  instructions?: string | null;

  @IsOptional()
  @IsIn(['NONE', 'MESSAGE_ONLY', 'VOUCHER_CODE'])
  mode?: string;

  @IsOptional()
  @IsBoolean()
  isEnabled?: boolean;

  @IsOptional()
  @IsISO8601()
  startsAt?: string | null;

  @IsOptional()
  @IsISO8601()
  endsAt?: string | null;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(365)
  expiryDays?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  probabilityPct?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  dailyCap?: number | null;

  @IsOptional()
  @IsInt()
  @Min(1)
  totalCap?: number | null;
}

export class UpdateSurveyRewardDto extends CreateSurveyRewardDto {
  @IsOptional()
  @IsString()
  @Matches(/\S/, { message: 'name không được để trống' })
  @MaxLength(200)
  declare name: string;
}

export class RedeemSurveyRewardDto {
  @IsString()
  @Matches(/\S/, { message: 'code không được để trống' })
  @MaxLength(100)
  code!: string;
}

export class SurveyClaimsQueryDto extends PaginationDto {
  @IsOptional()
  @IsUUID()
  campaignId?: string;

  @IsOptional()
  @IsIn(['ISSUED', 'REDEEMED', 'EXPIRED', 'VOID'])
  status?: string;
}

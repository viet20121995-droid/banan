import {
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
} from 'class-validator';

const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;

export class CreateWeekDto {
  /** Monday of the week, YYYY-MM-DD (any day is snapped to its Monday). */
  @IsISO8601()
  weekStart!: string;

  /** Optional: copy shifts + assignments from this week's schedule. */
  @IsOptional()
  @IsUUID()
  copyFromScheduleId?: string;
}

export class CreateShiftDto {
  @IsUUID()
  storeId!: string;

  @IsString()
  @MaxLength(50)
  label!: string;

  @Matches(HHMM)
  startTime!: string;

  @Matches(HHMM)
  endTime!: string;
}

export class UpdateShiftDto {
  @IsOptional()
  @IsString()
  @MaxLength(50)
  label?: string;

  @IsOptional()
  @Matches(HHMM)
  startTime?: string;

  @IsOptional()
  @Matches(HHMM)
  endTime?: string;
}

export class CreateAssignmentDto {
  @IsInt()
  @Min(0)
  @Max(6)
  dayOfWeek!: number;

  @IsOptional()
  @IsUUID()
  personId?: string;

  /** Free-text name — never blocked, warned only. */
  @IsOptional()
  @IsString()
  @MaxLength(100)
  freeName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}

export class UpdateAssignmentDto {
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(6)
  dayOfWeek?: number;

  @IsOptional()
  @IsUUID()
  personId?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  freeName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}

export class WeeksQueryDto {
  @IsOptional()
  @IsIn(['DRAFT', 'PUBLISHED', 'ARCHIVED'])
  status?: string;
}

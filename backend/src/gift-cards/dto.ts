import {
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class IssueGiftCardDto {
  @IsInt()
  @Min(1000)
  valueVnd!: number;

  @IsOptional()
  @IsISO8601()
  expiresAt?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}

export class ValidateGiftCardDto {
  @IsString()
  @MaxLength(40)
  code!: string;
}

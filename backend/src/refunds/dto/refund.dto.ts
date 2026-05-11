import { IsNumber, IsOptional, IsPositive, IsString, MaxLength, MinLength } from 'class-validator';

/** Customer-initiated explicit refund request (not used for cancel auto-refunds). */
export class RequestRefundDto {
  @IsNumber()
  @IsPositive()
  amount!: number;

  @IsString()
  @MinLength(3)
  @MaxLength(280)
  reason!: string;
}

export class RejectRefundDto {
  @IsOptional()
  @IsString()
  @MaxLength(280)
  reason?: string;
}

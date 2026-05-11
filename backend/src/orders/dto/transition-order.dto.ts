import { OrderStatus } from '@prisma/client';
import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';

export class TransitionOrderDto {
  @IsEnum(OrderStatus)
  toStatus!: OrderStatus;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  note?: string;
}

export class CancelOrderDto {
  @IsOptional()
  @IsString()
  @MaxLength(280)
  reason?: string;
}

import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class TransferToKitchenDto {
  @IsOptional()
  @IsUUID()
  kitchenId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  note?: string;
}

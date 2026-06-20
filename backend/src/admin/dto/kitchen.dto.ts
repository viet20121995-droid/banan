import { IsInt, IsOptional, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';

/** Create a production kitchen. A kitchen prepares orders for one or more
 *  branches; `capacityPerHour` is a soft cap used by the capacity planner. */
export class CreateKitchenDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(255)
  address!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100000)
  capacityPerHour?: number;
}

export class UpdateKitchenDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  address?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100000)
  capacityPerHour?: number;
}

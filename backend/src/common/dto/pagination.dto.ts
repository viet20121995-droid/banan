import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

/**
 * Shared query pagination. Validated at the boundary by the global
 * ValidationPipe (transform:true) so a non-integer, Infinity, or out-of-range
 * value is rejected with 400 — it can never reach Prisma `skip`/`take` (which
 * require finite integers) and cause a 500. Callers apply their own default +
 * a tighter per-endpoint max where needed.
 */
export class PaginationDto {
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

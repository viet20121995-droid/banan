import { BadRequestException, Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { IsOptional, IsString, MaxLength } from 'class-validator';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';
import { PaginationDto } from '../common/dto/pagination.dto';

import { CukcukKind, isCukcukKind } from './cukcuk-normalize';
import { CukcukService } from './cukcuk.service';

class SyncDto {
  /** One dataset, or `all`. */
  @IsOptional()
  @IsString()
  kind?: string;
}

class RecordsQuery extends PaginationDto {
  @IsString()
  kind!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  q?: string;
}

function kindOf(v: string | undefined): CukcukKind {
  if (!isCukcukKind(v)) {
    throw new BadRequestException({
      code: 'CUKCUK_KIND_INVALID',
      message: `Loại dữ liệu không hợp lệ: ${v}`,
    });
  }
  return v;
}

/// Internal ops app → "Update dữ liệu CukCuk". Admin only.
@ApiBearerAuth()
@ApiTags('internal.cukcuk')
@Controller({ path: 'internal/cukcuk', version: '1' })
@Roles(Role.ADMIN)
export class CukcukController {
  constructor(private readonly cukcuk: CukcukService) {}

  @Get('status')
  status() {
    return this.cukcuk.status();
  }

  @Post('sync')
  async sync(@Body() dto: SyncDto, @CurrentUser() user: AuthPrincipal) {
    if (!dto.kind || dto.kind === 'all') return this.cukcuk.syncAll(user.sub);
    const kind = kindOf(dto.kind);
    return [{ kind, fetched: await this.cukcuk.sync(kind, user.sub), error: null }];
  }

  @Get('records')
  records(@Query() q: RecordsQuery) {
    return this.cukcuk.list(kindOf(q.kind), q.q?.trim() || undefined, q.page ?? 1, q.perPage ?? 50);
  }

  @Get('records/:kind/:externalId')
  record(@Param('kind') kind: string, @Param('externalId') externalId: string) {
    return this.cukcuk.detail(kindOf(kind), externalId);
  }

  @Post('customers/apply')
  applyCustomers() {
    return this.cukcuk.applyCustomers();
  }
}

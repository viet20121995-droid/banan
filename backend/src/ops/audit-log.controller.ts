import { Controller, Get, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { Roles } from '../auth/decorators/roles.decorator';

import { AuditLogService } from './audit-log.service';

@ApiBearerAuth()
@ApiTags('admin')
@Controller({ path: 'admin/audit-log', version: '1' })
@Roles(Role.ADMIN)
export class AuditLogController {
  constructor(private readonly audit: AuditLogService) {}

  /** Staff action trail, newest first. `from`/`to` are VN calendar days. */
  @Get()
  list(
    @Query('q') q?: string,
    @Query('userId') userId?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('page') page?: string,
    @Query('perPage') perPage?: string,
  ) {
    const day = /^\d{4}-\d{2}-\d{2}$/;
    return this.audit.list({
      q,
      userId,
      from: from && day.test(from) ? from : undefined,
      to: to && day.test(to) ? to : undefined,
      page: Math.max(1, Number(page) || 1),
      perPage: Math.min(200, Math.max(1, Number(perPage) || 50)),
    });
  }
}

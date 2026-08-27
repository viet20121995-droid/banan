import { Body, Controller, Get, Param, Patch, Post, Query, Res } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import type { Response } from 'express';

import { CurrentUser } from '../../auth/decorators/current-user.decorator';
import { Roles } from '../../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../../auth/types/jwt-payload';
import { InternalReportDeliveryService } from '../internal-report-delivery.service';
import { ReportPdfQueryDto } from '../qc/dto';

import {
  CreateMsAssignmentDto,
  IssueTokenDto,
  MsListQueryDto,
  RequestRevisionDto,
  UpdateMsAssignmentDto,
} from './dto';
import { MsService } from './ms.service';

@ApiBearerAuth()
@ApiTags('internal.ms')
@Controller({ path: 'internal/ms', version: '1' })
@Roles(Role.ADMIN)
export class MsController {
  constructor(
    private readonly ms: MsService,
    private readonly deliveries: InternalReportDeliveryService,
  ) {}

  @Get('template')
  template() {
    return this.ms.activeTemplate();
  }

  @Get('assignments')
  list(@Query() query: MsListQueryDto) {
    return this.ms.list(query, query.page ?? 1, query.perPage ?? 30);
  }

  @Post('assignments')
  create(@Body() dto: CreateMsAssignmentDto, @CurrentUser() user: AuthPrincipal) {
    return this.ms.create(dto, user.sub);
  }

  @Get('assignments/:id')
  detail(@Param('id') id: string) {
    return this.ms.adminDetail(id);
  }

  @Patch('assignments/:id')
  update(
    @Param('id') id: string,
    @Body() dto: UpdateMsAssignmentDto,
    @CurrentUser() user: AuthPrincipal,
  ) {
    return this.ms.update(id, dto, user.sub);
  }

  @Post('assignments/:id/copy')
  copy(@Param('id') id: string, @CurrentUser() user: AuthPrincipal) {
    return this.ms.copy(id, user.sub);
  }

  @Post('assignments/:id/token')
  issueToken(
    @Param('id') id: string,
    @Body() dto: IssueTokenDto,
    @CurrentUser() user: AuthPrincipal,
  ) {
    return this.ms.issueToken(id, dto, user.sub);
  }

  @Post('assignments/:id/revoke')
  revoke(@Param('id') id: string, @CurrentUser() user: AuthPrincipal) {
    return this.ms.revoke(id, user.sub);
  }

  @Post('assignments/:id/request-revision')
  requestRevision(
    @Param('id') id: string,
    @Body() dto: RequestRevisionDto,
    @CurrentUser() user: AuthPrincipal,
  ) {
    return this.ms.requestRevision(id, dto, user.sub);
  }

  @Get('assignments/:id/result')
  result(@Param('id') id: string) {
    return this.ms.result(id);
  }

  @Post('assignments/:id/approve')
  async approve(@Param('id') id: string, @CurrentUser() user: AuthPrincipal) {
    const res = await this.ms.approve(id, user.sub);
    // Fire-and-forget — SMTP failure never rolls back the approval; the
    // outbox cron retries the committed delivery row.
    void this.deliveries.dispatchMs(res.assignmentId, res.revision);
    return this.ms.adminDetail(id);
  }

  /** Approved revisions come from the immutable delivery snapshot; a
   *  not-yet-approved assignment downloads as a watermarked draft. */
  @Get('assignments/:id/report.pdf')
  async reportPdf(
    @Param('id') id: string,
    @Query() query: ReportPdfQueryDto,
    @Res() res: Response,
  ) {
    const { bytes, filename } = await this.ms.downloadPdf(id, query.revision);
    res
      .status(200)
      .setHeader('Content-Type', 'application/pdf')
      .setHeader('Content-Disposition', `attachment; filename="${filename}"`)
      .send(bytes);
  }
}

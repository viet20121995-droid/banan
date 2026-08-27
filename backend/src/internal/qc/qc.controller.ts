import { Body, Controller, Delete, Get, Param, Patch, Post, Put, Query, Res } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import type { Response } from 'express';

import { CurrentUser } from '../../auth/decorators/current-user.decorator';
import { Roles } from '../../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../../auth/types/jwt-payload';
import { InternalReportDeliveryService } from '../internal-report-delivery.service';

import {
  AttachEvidenceDto,
  CreateQcInspectionDto,
  QcCompareQueryDto,
  QcListQueryDto,
  ReportPdfQueryDto,
  UpdateQcInspectionDto,
  UpsertQcAnswerDto,
  UpsertQcRiskDto,
} from './dto';
import { QcService } from './qc.service';

@ApiBearerAuth()
@ApiTags('internal.qc')
@Controller({ path: 'internal/qc', version: '1' })
@Roles(Role.ADMIN)
export class QcController {
  constructor(
    private readonly qc: QcService,
    private readonly deliveries: InternalReportDeliveryService,
  ) {}

  @Get('template')
  template() {
    return this.qc.activeTemplate();
  }

  @Get('inspections')
  list(@Query() query: QcListQueryDto) {
    return this.qc.list(query, query.page ?? 1, query.perPage ?? 30);
  }

  @Get('compare')
  compare(@Query() query: QcCompareQueryDto) {
    return this.qc.compare(query);
  }

  @Post('inspections')
  create(@Body() dto: CreateQcInspectionDto, @CurrentUser() user: AuthPrincipal) {
    return this.qc.create(dto, user.sub, user.email);
  }

  @Get('inspections/:id')
  detail(@Param('id') id: string) {
    return this.qc.detail(id);
  }

  @Patch('inspections/:id')
  update(
    @Param('id') id: string,
    @Body() dto: UpdateQcInspectionDto,
    @CurrentUser() user: AuthPrincipal,
  ) {
    return this.qc.updateHeader(id, dto, user.sub);
  }

  @Put('inspections/:id/answers/:itemId')
  answer(
    @Param('id') id: string,
    @Param('itemId') itemId: string,
    @Body() dto: UpsertQcAnswerDto,
    @CurrentUser() user: AuthPrincipal,
  ) {
    return this.qc.upsertAnswer(id, itemId, dto, user.sub);
  }

  @Put('inspections/:id/risks/:itemId')
  risk(
    @Param('id') id: string,
    @Param('itemId') itemId: string,
    @Body() dto: UpsertQcRiskDto,
    @CurrentUser() user: AuthPrincipal,
  ) {
    return this.qc.upsertRisk(id, itemId, dto, user.sub);
  }

  @Post('inspections/:id/answers/:itemId/evidence')
  attach(
    @Param('id') id: string,
    @Param('itemId') itemId: string,
    @Body() dto: AttachEvidenceDto,
    @CurrentUser() user: AuthPrincipal,
  ) {
    return this.qc.attachEvidence(id, itemId, dto, user.sub);
  }

  @Delete('inspections/:id/evidence/:evidenceId')
  removeEvidence(@Param('id') id: string, @Param('evidenceId') evidenceId: string) {
    return this.qc.removeEvidence(id, evidenceId);
  }

  /** Live score preview for the result screen (works pre-completion too). */
  @Get('inspections/:id/result')
  async result(@Param('id') id: string) {
    const bundle = await this.qc.reportBundle(id);
    return {
      outcome: bundle.result.outcome,
      overallPercent: bundle.result.overallPercent,
      overallPass: bundle.result.overallPass,
      overallApplicable: bundle.result.overallApplicable,
      riskOccurred: bundle.result.riskOccurred,
      sections: bundle.result.sections,
      failedItems: bundle.failedItems,
      occurredRisks: bundle.occurredRisks,
    };
  }

  @Post('inspections/:id/complete')
  async complete(@Param('id') id: string, @CurrentUser() user: AuthPrincipal) {
    const res = await this.qc.complete(id, user.sub);
    // Fire-and-forget: an email/SMTP problem never rolls back the result —
    // the outbox row is already committed and the cron retries it.
    void this.deliveries.dispatchQc(res.inspectionId, res.revision);
    return this.qc.detail(id);
  }

  @Post('inspections/:id/reopen')
  reopen(@Param('id') id: string, @CurrentUser() user: AuthPrincipal) {
    return this.qc.reopen(id, user.sub);
  }

  /** Approved revisions come from the immutable delivery snapshot; a
   *  not-yet-completed inspection downloads as a watermarked draft. */
  @Get('inspections/:id/report.pdf')
  async reportPdf(
    @Param('id') id: string,
    @Query() query: ReportPdfQueryDto,
    @Res() res: Response,
  ) {
    const { bytes, filename } = await this.qc.downloadPdf(id, query.revision);
    res
      .status(200)
      .setHeader('Content-Type', 'application/pdf')
      .setHeader('Content-Disposition', `attachment; filename="${filename}"`)
      .send(bytes);
  }
}

import { Body, Controller, Delete, Get, Param, Patch, Post, Put, Query, Res } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import type { Response } from 'express';

import { CurrentUser } from '../../auth/decorators/current-user.decorator';
import { Roles } from '../../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../../auth/types/jwt-payload';

import {
  CreateSurveyRewardDto,
  CreateSurveyTemplateDto,
  RedeemSurveyRewardDto,
  ReplaceSurveyQuestionsDto,
  SurveyCasesQueryDto,
  SurveyClaimsQueryDto,
  SurveyReportQueryDto,
  SurveyResponsesQueryDto,
  UpdateSurveyCaseDto,
  UpdateSurveyRewardDto,
  UpdateSurveyTemplateDto,
} from './dto';
import { SurveyService } from './survey.service';

/** Survey administration — reports, closed-loop cases, template editor and
 *  the reward foundation. ADMIN only; the guest surface lives in
 *  SurveyPublicController. */
@ApiBearerAuth()
@ApiTags('internal.survey')
@Controller({ path: 'internal/survey', version: '1' })
@Roles(Role.ADMIN)
export class SurveyController {
  constructor(private readonly survey: SurveyService) {}

  // ── reports ──
  @Get('reports/summary')
  summary(@Query() query: SurveyReportQueryDto) {
    return this.survey.reportSummary(query);
  }

  @Get('responses')
  responses(@Query() query: SurveyResponsesQueryDto) {
    return this.survey.listResponses(query);
  }

  @Get('reports/export.csv')
  async exportCsv(@Query() query: SurveyReportQueryDto, @Res() res: Response) {
    const csv = await this.survey.exportCsv(query);
    res
      .status(200)
      .setHeader('Content-Type', 'text/csv; charset=utf-8')
      .setHeader('Content-Disposition', 'attachment; filename="banan-survey.csv"')
      .send(csv);
  }

  // ── cases ──
  @Get('cases')
  cases(@Query() query: SurveyCasesQueryDto) {
    return this.survey.listCases(query);
  }

  @Patch('cases/:id')
  updateCase(
    @Param('id') id: string,
    @Body() dto: UpdateSurveyCaseDto,
    @CurrentUser() user: AuthPrincipal,
  ) {
    return this.survey.updateCase(id, dto, user.sub);
  }

  // ── templates ──
  @Get('templates')
  templates() {
    return this.survey.listTemplates();
  }

  @Post('templates')
  createTemplate(@Body() dto: CreateSurveyTemplateDto, @CurrentUser() user: AuthPrincipal) {
    return this.survey.createTemplate(dto, user.sub);
  }

  @Get('templates/:id')
  templateDetail(@Param('id') id: string) {
    return this.survey.templateDetail(id);
  }

  @Patch('templates/:id')
  updateTemplate(@Param('id') id: string, @Body() dto: UpdateSurveyTemplateDto) {
    return this.survey.updateTemplate(id, dto);
  }

  @Put('templates/:id/questions')
  replaceQuestions(@Param('id') id: string, @Body() dto: ReplaceSurveyQuestionsDto) {
    return this.survey.replaceQuestions(id, dto);
  }

  @Post('templates/:id/publish')
  publish(@Param('id') id: string) {
    return this.survey.publishTemplate(id);
  }

  @Post('templates/:id/archive')
  archive(@Param('id') id: string) {
    return this.survey.archiveTemplate(id);
  }

  @Delete('templates/:id')
  deleteTemplate(@Param('id') id: string) {
    return this.survey.deleteTemplate(id);
  }

  // ── rewards ──
  @Get('rewards')
  rewards() {
    return this.survey.listCampaigns();
  }

  @Post('rewards')
  createReward(@Body() dto: CreateSurveyRewardDto) {
    return this.survey.createCampaign(dto);
  }

  @Patch('rewards/:id')
  updateReward(@Param('id') id: string, @Body() dto: UpdateSurveyRewardDto) {
    return this.survey.updateCampaign(id, dto);
  }

  @Post('rewards/redeem')
  redeem(@Body() dto: RedeemSurveyRewardDto, @CurrentUser() user: AuthPrincipal) {
    return this.survey.redeemClaim(dto, user.sub);
  }

  @Get('rewards/claims')
  claims(@Query() query: SurveyClaimsQueryDto) {
    return this.survey.listClaims(query);
  }
}

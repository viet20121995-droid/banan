import { Body, Controller, Get, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';

import { Public } from '../../auth/decorators/public.decorator';
import { InternalReportDeliveryService } from '../internal-report-delivery.service';

import { PublicSurveySubmitDto } from './dto';
import { SurveyService } from './survey.service';

/**
 * Public dine-in survey endpoints behind the ONE fixed link (/survey).
 * No account, no token, no table/branch baked into the QR — the guest picks
 * the branch on the form and the server validates it against the live Store
 * table. No IP is stored; PII only with explicit consent.
 */
@ApiTags('internal.survey.public')
@Controller({ path: 'internal/survey/public', version: '1' })
export class SurveyPublicController {
  constructor(
    private readonly survey: SurveyService,
    private readonly deliveries: InternalReportDeliveryService,
  ) {}

  /** Published template + LIVE store list + reward teaser. */
  @Public()
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Get()
  info() {
    return this.survey.publicInfo();
  }

  /**
   * Submit — idempotent on `clientRequestId` (a retried submit returns the
   * SAME response + reward). Tight throttle: the only public endpoint that
   * creates rows.
   */
  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('responses')
  @HttpCode(HttpStatus.OK)
  async submit(@Body() dto: PublicSurveySubmitDto) {
    const { caseId, ...result } = await this.survey.submitPublic(dto);
    // Alert email AFTER the commit, fire-and-forget — the outbox row inside
    // the tx is the source of truth; the cron retries if this call dies.
    if (caseId) void this.deliveries.dispatchSurveyAlert(caseId);
    return result;
  }
}

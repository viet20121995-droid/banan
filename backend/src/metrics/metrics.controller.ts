import { BadRequestException, Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';

import { Public } from '../auth/decorators/public.decorator';

import { MetricsService } from './metrics.service';

/** Public beacon endpoint — the storefront fires it once per page load. */
@ApiTags('metrics')
@Controller({ path: 'metrics', version: '1' })
export class MetricsController {
  constructor(private readonly metrics: MetricsService) {}

  // A browser fires this once per load — 10/min/IP is plenty, and it caps
  // how fast a curl loop can pad the ops traffic report.
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Public()
  @Post('visit')
  @HttpCode(HttpStatus.NO_CONTENT)
  async visit(@Body() body: { visitorId?: unknown }): Promise<void> {
    const id = body?.visitorId;
    // Free-text from an unauthenticated endpoint — cap shape hard.
    if (typeof id !== 'string' || id.length < 8 || id.length > 64 || !/^[\w-]+$/.test(id)) {
      throw new BadRequestException({ code: 'INVALID_VISITOR_ID' });
    }
    await this.metrics.recordVisit(id);
  }
}

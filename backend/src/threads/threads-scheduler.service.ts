import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { ThreadsService } from './threads.service';

/**
 * Auto-publishes scheduled threads. Every 5 minutes it flips any draft
 * whose `scheduledPublishAt` is now in the past to published. Idempotent —
 * `publishDueScheduled()` only touches drafts.
 */
@Injectable()
export class ThreadsSchedulerService {
  private readonly logger = new Logger(ThreadsSchedulerService.name);

  constructor(private readonly threads: ThreadsService) {}

  @Cron(CronExpression.EVERY_5_MINUTES)
  async publishDue(): Promise<void> {
    const n = await this.threads.publishDueScheduled();
    if (n > 0) this.logger.log(`Auto-published ${n} scheduled thread(s)`);
  }
}

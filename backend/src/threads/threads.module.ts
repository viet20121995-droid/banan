import { Module } from '@nestjs/common';

import { MerchantThreadsController, ThreadsController } from './threads.controller';
import { ThreadsSchedulerService } from './threads-scheduler.service';
import { ThreadsService } from './threads.service';

@Module({
  controllers: [ThreadsController, MerchantThreadsController],
  providers: [ThreadsService, ThreadsSchedulerService],
})
export class ThreadsModule {}

import { Module } from '@nestjs/common';

import {
  MerchantThreadsController,
  ThreadsController,
} from './threads.controller';
import { ThreadsService } from './threads.service';

@Module({
  controllers: [ThreadsController, MerchantThreadsController],
  providers: [ThreadsService],
})
export class ThreadsModule {}

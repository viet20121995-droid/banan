import { Module } from '@nestjs/common';

import { AnalyticsService } from './analytics.service';
import {
  KitchenAnalyticsController,
  MerchantAnalyticsController,
} from './analytics.controller';

@Module({
  controllers: [MerchantAnalyticsController, KitchenAnalyticsController],
  providers: [AnalyticsService],
})
export class AnalyticsModule {}

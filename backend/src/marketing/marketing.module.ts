import { Module } from '@nestjs/common';

import {
  MarketingController,
  MerchantMarketingController,
} from './marketing.controller';
import { MarketingService } from './marketing.service';

@Module({
  controllers: [MarketingController, MerchantMarketingController],
  providers: [MarketingService],
})
export class MarketingModule {}

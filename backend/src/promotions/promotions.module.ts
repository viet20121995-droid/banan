import { Module } from '@nestjs/common';

import { CampaignsController } from './promotions.controller';
import { PromotionsService } from './promotions.service';

@Module({
  controllers: [CampaignsController],
  providers: [PromotionsService],
  exports: [PromotionsService],
})
export class PromotionsModule {}

import { Module } from '@nestjs/common';

import { CampaignsController } from './promotions.controller';
import { PromotionsPublicController } from './promotions-public.controller';
import { PromotionsService } from './promotions.service';

@Module({
  controllers: [CampaignsController, PromotionsPublicController],
  providers: [PromotionsService],
  exports: [PromotionsService],
})
export class PromotionsModule {}

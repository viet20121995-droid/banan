import { Module } from '@nestjs/common';

import {
  AdminPromoPopupController,
  PromoPopupController,
} from './promo-popup.controller';
import { PromoPopupService } from './promo-popup.service';

@Module({
  controllers: [PromoPopupController, AdminPromoPopupController],
  providers: [PromoPopupService],
})
export class PromoPopupModule {}

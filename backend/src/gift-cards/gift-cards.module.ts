import { Module } from '@nestjs/common';

import { GiftCardsController, MerchantGiftCardsController } from './gift-cards.controller';
import { GiftCardsService } from './gift-cards.service';

@Module({
  controllers: [GiftCardsController, MerchantGiftCardsController],
  providers: [GiftCardsService],
})
export class GiftCardsModule {}

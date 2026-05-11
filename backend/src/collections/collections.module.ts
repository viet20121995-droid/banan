import { Module } from '@nestjs/common';

import {
  CollectionsController,
  MerchantCollectionsController,
} from './collections.controller';
import { CollectionsService } from './collections.service';

@Module({
  controllers: [CollectionsController, MerchantCollectionsController],
  providers: [CollectionsService],
})
export class CollectionsModule {}

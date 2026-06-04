import { Module } from '@nestjs/common';

import {
  BundlesController,
  MerchantBundlesController,
} from './bundles.controller';
import { BundlesService } from './bundles.service';

@Module({
  controllers: [BundlesController, MerchantBundlesController],
  providers: [BundlesService],
  exports: [BundlesService],
})
export class BundlesModule {}

import { Module } from '@nestjs/common';

import {
  MerchantSiteContentController,
  SiteContentController,
} from './site-content.controller';
import { SiteContentService } from './site-content.service';

@Module({
  controllers: [SiteContentController, MerchantSiteContentController],
  providers: [SiteContentService],
})
export class SiteContentModule {}

import { Module } from '@nestjs/common';

import {
  BannersController,
  MerchantBannersController,
} from './banners.controller';
import { BannersService } from './banners.service';

@Module({
  controllers: [BannersController, MerchantBannersController],
  providers: [BannersService],
})
export class BannersModule {}

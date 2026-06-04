import { Module } from '@nestjs/common';

import {
  CouponsController,
  MerchantCouponsController,
} from './coupons.controller';
import { CouponsService } from './coupons.service';

@Module({
  controllers: [CouponsController, MerchantCouponsController],
  providers: [CouponsService],
  exports: [CouponsService],
})
export class CouponsModule {}

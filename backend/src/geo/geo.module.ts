import { Module } from '@nestjs/common';

import { DeliveryConfigService } from './delivery-config.service';
import { GeoController } from './geo.controller';
import { StoreRouterService } from './store-router.service';

@Module({
  controllers: [GeoController],
  providers: [StoreRouterService, DeliveryConfigService],
  exports: [StoreRouterService, DeliveryConfigService],
})
export class GeoModule {}

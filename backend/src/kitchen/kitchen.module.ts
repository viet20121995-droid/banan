import { Module } from '@nestjs/common';

import { OrdersModule } from '../orders/orders.module';

import { KitchenController } from './kitchen.controller';

@Module({
  imports: [OrdersModule],
  controllers: [KitchenController],
})
export class KitchenModule {}

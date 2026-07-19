import { Module } from '@nestjs/common';

import { OrdersModule } from '../orders/orders.module';

import { AdminWholesaleController, WholesaleController } from './wholesale.controller';
import { WholesaleService } from './wholesale.service';

@Module({
  imports: [OrdersModule],
  controllers: [AdminWholesaleController, WholesaleController],
  providers: [WholesaleService],
})
export class WholesaleModule {}

import { Module } from '@nestjs/common';

import { NotificationsModule } from '../notifications/notifications.module';
import { OrdersModule } from '../orders/orders.module';

import { WholesaleSchedulerService } from './wholesale-scheduler.service';
import { AdminWholesaleController, WholesaleController } from './wholesale.controller';
import { WholesaleService } from './wholesale.service';

@Module({
  imports: [OrdersModule, NotificationsModule],
  controllers: [AdminWholesaleController, WholesaleController],
  providers: [WholesaleService, WholesaleSchedulerService],
})
export class WholesaleModule {}

import { Module } from '@nestjs/common';

import { CouponsModule } from '../coupons/coupons.module';
import { LoyaltyModule } from '../loyalty/loyalty.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PaymentsModule } from '../payments/payments.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { RefundsModule } from '../refunds/refunds.module';

import { MerchantOrdersController, OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';

@Module({
  imports: [
    RealtimeModule,
    PaymentsModule,
    RefundsModule,
    LoyaltyModule,
    CouponsModule,
    NotificationsModule,
  ],
  controllers: [OrdersController, MerchantOrdersController],
  providers: [OrdersService],
  exports: [OrdersService],
})
export class OrdersModule {}

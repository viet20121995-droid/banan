import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { CouponsModule } from '../coupons/coupons.module';
import { GeoModule } from '../geo/geo.module';
import { LoyaltyModule } from '../loyalty/loyalty.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PaymentsModule } from '../payments/payments.module';
import { PromotionsModule } from '../promotions/promotions.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { RefundsModule } from '../refunds/refunds.module';

import { MerchantOrdersController, OrdersController } from './orders.controller';
import { OrdersSchedulerService } from './orders-scheduler.service';
import { OrdersService } from './orders.service';

@Module({
  imports: [
    AuthModule,
    RealtimeModule,
    PaymentsModule,
    RefundsModule,
    LoyaltyModule,
    CouponsModule,
    NotificationsModule,
    GeoModule,
    PromotionsModule,
  ],
  controllers: [OrdersController, MerchantOrdersController],
  providers: [OrdersService, OrdersSchedulerService],
  exports: [OrdersService],
})
export class OrdersModule {}

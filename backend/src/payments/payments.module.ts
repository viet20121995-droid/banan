import { Module } from '@nestjs/common';

import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';

import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { CashPaymentService } from './providers/cash.service';
import { MoMoPaymentService } from './providers/momo.service';
import { NinePayPaymentService } from './providers/ninepay.service';
import { PayOSPaymentService } from './providers/payos.service';
import { StripePaymentService } from './providers/stripe.service';

@Module({
  imports: [RealtimeModule, NotificationsModule],
  controllers: [PaymentsController],
  providers: [
    PaymentsService,
    CashPaymentService,
    StripePaymentService,
    PayOSPaymentService,
    MoMoPaymentService,
    NinePayPaymentService,
  ],
  exports: [PaymentsService],
})
export class PaymentsModule {}

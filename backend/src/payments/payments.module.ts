import { Module } from '@nestjs/common';

import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { CashPaymentService } from './providers/cash.service';
import { MoMoPaymentService } from './providers/momo.service';
import { PayOSPaymentService } from './providers/payos.service';
import { StripePaymentService } from './providers/stripe.service';

@Module({
  controllers: [PaymentsController],
  providers: [
    PaymentsService,
    CashPaymentService,
    StripePaymentService,
    PayOSPaymentService,
    MoMoPaymentService,
  ],
  exports: [PaymentsService],
})
export class PaymentsModule {}

import { Module } from '@nestjs/common';

import { LoyaltyModule } from '../loyalty/loyalty.module';
import { NotificationsModule } from '../notifications/notifications.module';

import { CustomersController } from './customers.controller';
import { CustomersService } from './customers.service';

@Module({
  imports: [LoyaltyModule, NotificationsModule],
  controllers: [CustomersController],
  providers: [CustomersService],
})
export class CustomersModule {}

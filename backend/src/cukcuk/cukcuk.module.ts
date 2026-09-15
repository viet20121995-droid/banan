import { Module } from '@nestjs/common';

import { LoyaltyModule } from '../loyalty/loyalty.module';

import { CukcukPublicController } from './cukcuk-public.controller';
import { CukcukClient } from './cukcuk.client';
import { CukcukController } from './cukcuk.controller';
import { CukcukService } from './cukcuk.service';

/// MISA CukCuk POS sync — pulls branches, menu, customers, invoices and open
/// orders into `CukcukRecord` for the internal ops app.
@Module({
  imports: [LoyaltyModule],
  controllers: [CukcukController, CukcukPublicController],
  providers: [CukcukClient, CukcukService],
  exports: [CukcukService],
})
export class CukcukModule {}

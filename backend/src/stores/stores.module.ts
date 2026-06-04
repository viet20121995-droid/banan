import { Module } from '@nestjs/common';

import { MerchantStoreController, StoresController } from './stores.controller';
import { StoresService } from './stores.service';

@Module({
  controllers: [StoresController, MerchantStoreController],
  providers: [StoresService],
  exports: [StoresService],
})
export class StoresModule {}

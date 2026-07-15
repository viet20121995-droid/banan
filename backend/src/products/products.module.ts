import { Module } from '@nestjs/common';

import { BundlesModule } from '../bundles/bundles.module';

import { ProductsBulkService } from './products-bulk.service';
import { ProductsController } from './products.controller';
import { ProductsService } from './products.service';

@Module({
  imports: [BundlesModule],
  controllers: [ProductsController],
  providers: [ProductsService, ProductsBulkService],
  exports: [ProductsService],
})
export class ProductsModule {}

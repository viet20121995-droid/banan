import { Module } from '@nestjs/common';

import { ProductsBulkService } from './products-bulk.service';
import { ProductsController } from './products.controller';
import { ProductsService } from './products.service';

@Module({
  controllers: [ProductsController],
  providers: [ProductsService, ProductsBulkService],
})
export class ProductsModule {}

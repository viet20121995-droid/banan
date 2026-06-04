import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import { BulkImportDto, BulkPriceDto } from './dto/bulk.dto';
import { CreateProductDto } from './dto/create-product.dto';
import { ListProductsDto } from './dto/list-products.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { ProductsBulkService } from './products-bulk.service';
import { ProductsService } from './products.service';

@ApiTags('products')
@Controller({ path: 'products', version: '1' })
export class ProductsController {
  constructor(
    private readonly products: ProductsService,
    private readonly bulk: ProductsBulkService,
  ) {}

  @Public()
  @Get()
  async findAll(@Query() q: ListProductsDto) {
    return this.products.findAll(q);
  }

  @Public()
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.products.findOne(id);
  }

  /// "Khách cũng mua" recommendations — public so the product detail
  /// section is visible to anonymous browsers too.
  @Public()
  @Get(':id/recommendations')
  recommendations(
    @Param('id') id: string,
    @Query('limit') limit?: string,
  ) {
    return this.products.recommendations(id, Number(limit) || 8);
  }

  // ── Chain-wide menu management ─────────────────────────────────────────
  // All merchant CRUD operates on the single shared catalog store. Doesn't
  // matter which branch the merchant runs — they all edit the same menu,
  // and every customer sees the changes instantly.
  // Per-branch logic (orders queue, pickup routing) is unaffected — that
  // still uses `user.storeId` everywhere else.

  @Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
  @Get('merchant/list')
  async findAllForStore(
    @CurrentUser() _user: AuthPrincipal,
    @Query() q: ListProductsDto,
  ) {
    const storeId = await this.products.catalogStoreId();
    return this.products.findAllForStore(storeId, q);
  }

  @Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
  @Post()
  async create(
    @CurrentUser() _user: AuthPrincipal,
    @Body() dto: CreateProductDto,
  ) {
    const storeId = await this.products.catalogStoreId();
    return this.products.create(storeId, dto);
  }

  @Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
  @Patch(':id')
  async update(
    @CurrentUser() _user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: UpdateProductDto,
  ) {
    // Pass `null` so the service skips the per-store ownership check — the
    // catalog is shared across the chain.
    return this.products.update(id, null, dto);
  }

  @Roles(Role.MERCHANT_OWNER, Role.ADMIN)
  @Delete(':id')
  async remove(@CurrentUser() _user: AuthPrincipal, @Param('id') id: string) {
    // Returns `{ deleted, archived }` so the UI shows the right outcome
    // ("Đã xoá" vs "Đã ẩn vì có đơn cũ"). 200 OK so the body comes through.
    return this.products.remove(id, null);
  }

  @Roles(Role.MERCHANT_OWNER, Role.ADMIN)
  @Post(':id/restore')
  async restore(@CurrentUser() _user: AuthPrincipal, @Param('id') id: string) {
    return this.products.restore(id, null);
  }

  // ── Bulk ops (P4 #31/#32) — owner/admin only ───────────────────────────

  /// CSV product import. Rows are parsed client-side; here we create-only
  /// (skip existing slugs) so re-runs are safe. Returns created/skipped/errors.
  @Roles(Role.MERCHANT_OWNER, Role.ADMIN)
  @Post('merchant/bulk-import')
  @HttpCode(HttpStatus.OK)
  async bulkImport(
    @CurrentUser() _user: AuthPrincipal,
    @Body() dto: BulkImportDto,
  ) {
    const storeId = await this.products.catalogStoreId();
    return this.bulk.bulkImport(storeId, dto);
  }

  /// Bulk price adjustment over all / a category / a collection. Supports
  /// `dryRun` for a preview before committing.
  @Roles(Role.MERCHANT_OWNER, Role.ADMIN)
  @Post('merchant/bulk-price')
  @HttpCode(HttpStatus.OK)
  async bulkPrice(
    @CurrentUser() _user: AuthPrincipal,
    @Body() dto: BulkPriceDto,
  ) {
    return this.bulk.bulkPrice(dto);
  }
}

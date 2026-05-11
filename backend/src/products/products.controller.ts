import {
  BadRequestException,
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

import { CreateProductDto } from './dto/create-product.dto';
import { ListProductsDto } from './dto/list-products.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { ProductsService } from './products.service';

@ApiTags('products')
@Controller({ path: 'products', version: '1' })
export class ProductsController {
  constructor(private readonly products: ProductsService) {}

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

  @Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
  @Get('merchant/list')
  findAllForStore(@CurrentUser() user: AuthPrincipal, @Query() q: ListProductsDto) {
    if (!user.storeId && user.role !== Role.ADMIN) {
      throw new BadRequestException({ code: 'NO_STORE_ASSIGNED' });
    }
    const storeId = user.storeId ?? q.storeId;
    if (!storeId) {
      throw new BadRequestException({ code: 'STORE_ID_REQUIRED' });
    }
    return this.products.findAllForStore(storeId, q);
  }

  @Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
  @Post()
  create(@CurrentUser() user: AuthPrincipal, @Body() dto: CreateProductDto) {
    if (!user.storeId) {
      throw new BadRequestException({ code: 'NO_STORE_ASSIGNED' });
    }
    return this.products.create(user.storeId, dto);
  }

  @Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
  @Patch(':id')
  update(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: UpdateProductDto,
  ) {
    return this.products.update(id, user.role === Role.ADMIN ? null : (user.storeId ?? null), dto);
  }

  @Roles(Role.MERCHANT_OWNER, Role.ADMIN)
  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':id')
  remove(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.products.remove(id, user.role === Role.ADMIN ? null : (user.storeId ?? null));
  }
}

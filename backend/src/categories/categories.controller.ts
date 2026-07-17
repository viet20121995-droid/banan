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

import { CategoriesService } from './categories.service';
import { CreateCategoryDto, ReorderCategoriesDto, UpdateCategoryDto } from './dto/category.dto';

@ApiTags('categories')
@Controller({ path: 'categories', version: '1' })
export class CategoriesController {
  constructor(private readonly categories: CategoriesService) {}

  @Public()
  @Get()
  findAll(@CurrentUser() user?: AuthPrincipal, @Query('includeHidden') includeHidden?: string) {
    // Only staff (merchant back-office) may list hidden categories; the public
    // storefront always gets visible-only, even if it passes the flag.
    const privileged =
      user?.role === Role.ADMIN ||
      user?.role === Role.MERCHANT_OWNER ||
      user?.role === Role.MERCHANT_STAFF;
    return this.categories.findAll(privileged && includeHidden === 'true');
  }

  /** Customer home — pinned categories with a few products each (declared
   *  before :id so "home" isn't captured as an id). */
  @Public()
  @Get('home')
  home() {
    return this.categories.homePinned();
  }

  @Public()
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.categories.findOne(id);
  }

  @Roles(Role.ADMIN)
  @Post()
  create(@Body() dto: CreateCategoryDto) {
    return this.categories.create(dto);
  }

  /** Drag-to-reorder: full id list in the new order (before :id). */
  @Roles(Role.ADMIN)
  @HttpCode(HttpStatus.NO_CONTENT)
  @Patch('reorder')
  reorder(@Body() dto: ReorderCategoriesDto) {
    return this.categories.reorder(dto.ids);
  }

  @Roles(Role.ADMIN)
  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateCategoryDto) {
    return this.categories.update(id, dto);
  }

  @Roles(Role.ADMIN)
  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':id')
  remove(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Query('force') force?: string,
  ) {
    // force=true also hard-deletes the category's products (admin is chain-wide
    // → storeId null; ProductsService still enforces per-product order safety).
    return force === 'true'
      ? this.categories.removeWithProducts(id, user.storeId ?? null)
      : this.categories.remove(id);
  }
}

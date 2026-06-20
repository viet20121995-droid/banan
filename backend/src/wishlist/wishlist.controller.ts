import { Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import { WishlistService } from './wishlist.service';

@ApiBearerAuth()
@ApiTags('wishlist')
@Controller({ path: 'wishlist', version: '1' })
@Roles(Role.CUSTOMER)
export class WishlistController {
  constructor(private readonly wishlist: WishlistService) {}

  @Get()
  list(
    @CurrentUser() user: AuthPrincipal,
    @Query('page') page?: string,
    @Query('perPage') perPage?: string,
  ) {
    return this.wishlist.list(user.sub, Number(page) || 1, Number(perPage) || 30);
  }

  /// Lightweight — just `{ productIds: [...] }` for the menu screen to mark
  /// hearts on the catalog without re-fetching product data we already have.
  @Get('ids')
  async ids(@CurrentUser() user: AuthPrincipal) {
    return { productIds: await this.wishlist.listProductIds(user.sub) };
  }

  @Post(':productId')
  add(@CurrentUser() user: AuthPrincipal, @Param('productId') productId: string) {
    return this.wishlist.add(user.sub, productId);
  }

  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':productId')
  remove(@CurrentUser() user: AuthPrincipal, @Param('productId') productId: string) {
    return this.wishlist.remove(user.sub, productId);
  }
}

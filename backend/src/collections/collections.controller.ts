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
import { merchantStoreScope } from '../common/merchant-scope';

import { CollectionsService } from './collections.service';
import {
  AddCollectionItemsDto,
  CreateCollectionDto,
  UpdateCollectionDto,
} from './dto/collection.dto';

@ApiTags('collections')
@Controller({ path: 'collections', version: '1' })
export class CollectionsController {
  constructor(private readonly collections: CollectionsService) {}

  /** Customer home — pinned, active collections only. */
  @Public()
  @Get('home')
  home(@Query('storeId') storeId?: string) {
    return this.collections.listForHome(storeId);
  }

  @Public()
  @Get(':id')
  findOne(@Param('id') id: string, @CurrentUser() user?: AuthPrincipal) {
    // Optional-auth: owning-store staff/admin can load an inactive collection
    // (the merchant editor uses this route); the public only gets active ones.
    return this.collections.findOnePublic(id, user);
  }
}

@ApiTags('merchant.collections')
@Controller({ path: 'merchant/collections', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
export class MerchantCollectionsController {
  constructor(private readonly collections: CollectionsService) {}

  @Get()
  list(@CurrentUser() user: AuthPrincipal) {
    // Admin has no assigned store — show every store's collections.
    if (user.role === Role.ADMIN) {
      return this.collections.listForStore(null);
    }
    if (!user.storeId) {
      throw new BadRequestException({ code: 'NO_STORE_ASSIGNED' });
    }
    return this.collections.listForStore(user.storeId);
  }

  @Get(':id')
  findOne(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.collections.findOne(
      id,
      merchantStoreScope(user),
    );
  }

  // Collections are chain-wide catalog content, managed by admin only. New
  // ones attach to the catalog store (admin has no branch storeId). Merchants
  // can still LIST/view (read-only), but not create/edit/delete.
  @Roles(Role.ADMIN)
  @Post()
  async create(
    @CurrentUser() _user: AuthPrincipal,
    @Body() dto: CreateCollectionDto,
  ) {
    const storeId = await this.collections.catalogStoreId();
    return this.collections.create(storeId, dto);
  }

  @Roles(Role.ADMIN)
  @Patch(':id')
  update(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: UpdateCollectionDto,
  ) {
    // Admin scope = null → may edit any collection.
    return this.collections.update(id, merchantStoreScope(user), dto);
  }

  // Append products to an existing collection (the "Add to collection" flow).
  @Roles(Role.ADMIN)
  @Post(':id/items')
  addItems(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: AddCollectionItemsDto,
  ) {
    return this.collections.addItems(id, merchantStoreScope(user), dto.productIds);
  }

  @Roles(Role.ADMIN)
  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':id')
  remove(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.collections.remove(id, merchantStoreScope(user));
  }
}

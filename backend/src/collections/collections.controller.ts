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
import { CreateCollectionDto, UpdateCollectionDto } from './dto/collection.dto';

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
  findOne(@Param('id') id: string) {
    return this.collections.findOneActive(id);
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

  // A collection belongs to one store; create has no chain-wide mode, so
  // it's a store-staff operation. Admin can still list (chain-wide above)
  // and delete, but creating requires a concrete store.
  @Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF)
  @Post()
  create(@CurrentUser() user: AuthPrincipal, @Body() dto: CreateCollectionDto) {
    if (!user.storeId) {
      throw new BadRequestException({ code: 'NO_STORE_ASSIGNED' });
    }
    return this.collections.create(user.storeId, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: UpdateCollectionDto,
  ) {
    return this.collections.update(
      id,
      merchantStoreScope(user),
      dto,
    );
  }

  @Roles(Role.MERCHANT_OWNER, Role.ADMIN)
  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':id')
  remove(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.collections.remove(
      id,
      merchantStoreScope(user),
    );
  }
}

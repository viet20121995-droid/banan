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

import { CreateThreadDto, UpdateThreadDto } from './dto/thread.dto';
import { ThreadsService } from './threads.service';

@ApiTags('threads')
@Controller({ path: 'threads', version: '1' })
export class ThreadsController {
  constructor(private readonly threads: ThreadsService) {}

  /** Public feed — published only, newest first. Optional `hashtag` filter. */
  @Public()
  @Get()
  list(
    @Query('storeId') storeId?: string,
    @Query('limit') limit?: string,
    @Query('hashtag') hashtag?: string,
  ) {
    return this.threads.listPublished({
      storeId,
      hashtag,
      limit: Number(limit) || 10,
    });
  }

  @Public()
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.threads.findOnePublished(id);
  }

  /** Public — fire-and-forget impression tracking from the customer feed. */
  @Public()
  @Post(':id/view')
  @HttpCode(HttpStatus.NO_CONTENT)
  async trackView(@Param('id') id: string) {
    await this.threads.incrementView(id);
  }
}

@ApiTags('merchant.threads')
@Controller({ path: 'merchant/threads', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
export class MerchantThreadsController {
  constructor(private readonly threads: ThreadsService) {}

  // Threads (store editorial posts) are scoped to a single store, and
  // listForStore has no chain-wide mode — so this is a store-staff
  // operation; admin (no storeId) is excluded rather than 400-ing with a
  // misleading "no store assigned".
  @Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF)
  @Get()
  list(@CurrentUser() user: AuthPrincipal) {
    if (!user.storeId) {
      throw new BadRequestException({ code: 'NO_STORE_ASSIGNED' });
    }
    return this.threads.listForStore(user.storeId);
  }

  @Get(':id')
  findOne(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.threads.findOne(
      id,
      merchantStoreScope(user),
    );
  }

  @Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF)
  @Post()
  create(@CurrentUser() user: AuthPrincipal, @Body() dto: CreateThreadDto) {
    if (!user.storeId) {
      throw new BadRequestException({ code: 'NO_STORE_ASSIGNED' });
    }
    return this.threads.create(user.storeId, user.sub, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: UpdateThreadDto,
  ) {
    return this.threads.update(
      id,
      merchantStoreScope(user),
      dto,
    );
  }

  @Roles(Role.MERCHANT_OWNER, Role.ADMIN)
  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':id')
  remove(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.threads.remove(
      id,
      merchantStoreScope(user),
    );
  }
}

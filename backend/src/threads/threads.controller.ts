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
  findOne(@Param('id') id: string, @CurrentUser() user?: AuthPrincipal) {
    // Optional-auth: the owning store's staff/admin can load a draft here
    // (the merchant editor uses this route); the public only gets published.
    return this.threads.findOnePublic(id, user);
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
// Posts (threads) are chain-wide editorial content, managed by ADMIN only.
// New posts attach to the catalog store; admin (scope null) lists/edits all.
@Roles(Role.ADMIN)
export class MerchantThreadsController {
  constructor(private readonly threads: ThreadsService) {}

  @Get()
  list(@CurrentUser() user: AuthPrincipal) {
    // Admin scope = null → every store's posts.
    return this.threads.listForStore(merchantStoreScope(user));
  }

  @Get(':id')
  findOne(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.threads.findOne(id, merchantStoreScope(user));
  }

  @Post()
  async create(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: CreateThreadDto,
  ) {
    const storeId = await this.threads.catalogStoreId();
    return this.threads.create(storeId, user.sub, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: UpdateThreadDto,
  ) {
    return this.threads.update(id, merchantStoreScope(user), dto);
  }

  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':id')
  remove(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.threads.remove(id, merchantStoreScope(user));
  }
}

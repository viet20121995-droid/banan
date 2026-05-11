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

import { CreateThreadDto, UpdateThreadDto } from './dto/thread.dto';
import { ThreadsService } from './threads.service';

@ApiTags('threads')
@Controller({ path: 'threads', version: '1' })
export class ThreadsController {
  constructor(private readonly threads: ThreadsService) {}

  /** Public feed — published only, newest first. */
  @Public()
  @Get()
  list(
    @Query('storeId') storeId?: string,
    @Query('limit') limit?: string,
  ) {
    return this.threads.listPublished({
      storeId,
      limit: Number(limit) || 10,
    });
  }

  @Public()
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.threads.findOne(id, null);
  }
}

@ApiTags('merchant.threads')
@Controller({ path: 'merchant/threads', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
export class MerchantThreadsController {
  constructor(private readonly threads: ThreadsService) {}

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
      user.role === Role.ADMIN ? null : (user.storeId ?? null),
    );
  }

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
      user.role === Role.ADMIN ? null : (user.storeId ?? null),
      dto,
    );
  }

  @Roles(Role.MERCHANT_OWNER, Role.ADMIN)
  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':id')
  remove(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.threads.remove(
      id,
      user.role === Role.ADMIN ? null : (user.storeId ?? null),
    );
  }
}

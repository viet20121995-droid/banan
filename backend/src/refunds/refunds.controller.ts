import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { RefundStatus, Role } from '@prisma/client';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import { RejectRefundDto } from './dto/refund.dto';
import { RefundsService } from './refunds.service';

@ApiBearerAuth()
@ApiTags('refunds')
@Controller({ path: 'refunds', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
export class RefundsController {
  constructor(private readonly refunds: RefundsService) {}

  @Get()
  list(
    @CurrentUser() user: AuthPrincipal,
    @Query('status') status?: RefundStatus,
    @Query('page') page?: string,
    @Query('perPage') perPage?: string,
  ) {
    if (!user.storeId && user.role !== Role.ADMIN) {
      throw new BadRequestException({ code: 'NO_STORE_ASSIGNED' });
    }
    return this.refunds.listForStore(user.storeId ?? null, {
      status,
      page: Number(page) || 1,
      perPage: Number(perPage) || 30,
    });
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.refunds.findOne(id);
  }

  @Roles(Role.MERCHANT_OWNER, Role.ADMIN)
  @Post(':id/approve')
  approve(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.refunds.approve(id, user);
  }

  @Roles(Role.MERCHANT_OWNER, Role.ADMIN)
  @Post(':id/reject')
  reject(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: RejectRefundDto,
  ) {
    return this.refunds.reject(id, user, dto.reason);
  }
}

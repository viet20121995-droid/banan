import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { OrderStatus, Role } from '@prisma/client';
import type { Request } from 'express';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import { CreateOrderDto } from './dto/create-order.dto';
import { IssueInvoiceDto } from './dto/issue-invoice.dto';
import { TransferToKitchenDto } from './dto/transfer-order.dto';
import { CancelOrderDto, TransitionOrderDto } from './dto/transition-order.dto';
import { OrdersService } from './orders.service';

@ApiBearerAuth()
@ApiTags('orders')
@Controller({ path: 'orders', version: '1' })
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  /**
   * Public endpoint — supports both authenticated customers and guests.
   * Guests must supply `guestFullName` + `guestPhone` (and optionally
   * `guestEmail` + `guestBirthday`) on the DTO; the service upserts a
   * CUSTOMER user keyed by phone before persisting the order.
   */
  @Public()
  @Post()
  create(
    @CurrentUser() user: AuthPrincipal | null,
    @Body() dto: CreateOrderDto,
    @Req() req: Request,
  ) {
    return this.orders.create(user?.sub ?? null, dto, req.ip ?? '0.0.0.0');
  }

  @Roles(Role.CUSTOMER)
  @Get()
  list(
    @CurrentUser() user: AuthPrincipal,
    @Query('page') page?: string,
    @Query('perPage') perPage?: string,
  ) {
    return this.orders.listForCustomer(user.sub, Number(page) || 1, Number(perPage) || 20);
  }

  @Get(':id')
  findOne(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.orders.findOne(id, user);
  }

  @Roles(Role.CUSTOMER)
  @Post(':id/cancel')
  cancel(@CurrentUser() user: AuthPrincipal, @Param('id') id: string, @Body() dto: CancelOrderDto) {
    return this.orders.customerCancel(id, user.sub, dto.reason);
  }
}

@ApiBearerAuth()
@ApiTags('merchant.orders')
@Controller({ path: 'merchant/orders', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
export class MerchantOrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Get()
  list(
    @CurrentUser() user: AuthPrincipal,
    @Query('status') status?: OrderStatus,
    @Query('page') page?: string,
    @Query('perPage') perPage?: string,
  ) {
    if (!user.storeId && user.role !== Role.ADMIN) {
      throw new BadRequestException({ code: 'NO_STORE_ASSIGNED' });
    }
    // Admin has no storeId → list across every store. Merchants stay
    // scoped to the store they own/operate.
    return this.orders.listForStore(user.storeId ?? null, {
      status,
      page: Number(page) || 1,
      perPage: Number(perPage) || 30,
    });
  }

  @Get(':id')
  findOne(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.orders.findOne(id, user);
  }

  @Post(':id/transition')
  @HttpCode(HttpStatus.OK)
  transition(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: TransitionOrderDto,
  ) {
    return this.orders.transition(id, dto.toStatus, user, dto.note);
  }

  @Post(':id/transfer-to-kitchen')
  @HttpCode(HttpStatus.OK)
  transferToKitchen(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: TransferToKitchenDto,
  ) {
    return this.orders.transferToKitchen(id, user, {
      kitchenId: dto.kitchenId,
      note: dto.note,
    });
  }

  /// VAT-invoice issuance — fills `invoiceIssuedAt` (now) and (optionally)
  /// `invoiceFileUrl`. Only the merchants of the fulfilling store + admin
  /// can do this; rejects if the order didn't request an invoice.
  @Patch(':id/invoice')
  @HttpCode(HttpStatus.OK)
  issueInvoice(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: IssueInvoiceDto,
  ) {
    return this.orders.issueInvoice(id, user, dto.invoiceFileUrl);
  }
}

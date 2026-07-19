import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseEnumPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { OrderStatus, Role, WholesaleReceivableStatus } from '@prisma/client';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import {
  ContractLineDto,
  CreateContractDto,
  CreateWholesaleAccountDto,
  CreateWholesaleOrderDto,
  RejectWholesaleOrderDto,
  UpdateContractDto,
  UpdateContractLineDto,
  UpdateWholesaleAccountDto,
} from './dto/wholesale.dto';
import { WholesaleService } from './wholesale.service';

/**
 * ADMIN ONLY — merchant owners/staff are deliberately excluded: wholesale
 * pricing, contracts and receivables are chain-level commercial terms.
 */
@ApiBearerAuth()
@ApiTags('admin.wholesale')
@Controller({ path: 'admin/wholesale', version: '1' })
@Roles(Role.ADMIN)
export class AdminWholesaleController {
  constructor(private readonly wholesale: WholesaleService) {}

  @Post('accounts')
  createAccount(@Body() dto: CreateWholesaleAccountDto) {
    return this.wholesale.createAccount(dto);
  }

  @Get('accounts')
  listAccounts() {
    return this.wholesale.listAccounts();
  }

  @Get('accounts/:id')
  getAccount(@Param('id') id: string) {
    return this.wholesale.getAccount(id);
  }

  @Patch('accounts/:id')
  updateAccount(@Param('id') id: string, @Body() dto: UpdateWholesaleAccountDto) {
    return this.wholesale.updateAccount(id, dto);
  }

  @Post('contracts')
  createContract(@Body() dto: CreateContractDto) {
    return this.wholesale.createContract(dto);
  }

  @Patch('contracts/:id')
  updateContract(@Param('id') id: string, @Body() dto: UpdateContractDto) {
    return this.wholesale.updateContract(id, dto);
  }

  @Post('contracts/:id/lines')
  addLine(@Param('id') id: string, @Body() dto: ContractLineDto) {
    return this.wholesale.addContractLine(id, dto);
  }

  @Patch('contracts/:id/lines/:lineId')
  updateLine(
    @Param('id') id: string,
    @Param('lineId') lineId: string,
    @Body() dto: UpdateContractLineDto,
  ) {
    return this.wholesale.updateContractLine(id, lineId, dto);
  }

  @Get('orders')
  listOrders(
    @Query('status', new ParseEnumPipe(OrderStatus, { optional: true }))
    status?: OrderStatus,
  ) {
    return this.wholesale.listOrdersAdmin(status);
  }

  @Post('orders/:id/confirm')
  @HttpCode(HttpStatus.OK)
  confirmOrder(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.wholesale.confirmOrder(id, user);
  }

  @Post('orders/:id/reject')
  @HttpCode(HttpStatus.OK)
  rejectOrder(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: RejectWholesaleOrderDto,
  ) {
    return this.wholesale.rejectOrder(id, user, dto.reason);
  }

  @Get('receivables')
  listReceivables(
    @Query('status', new ParseEnumPipe(WholesaleReceivableStatus, { optional: true }))
    status?: WholesaleReceivableStatus,
  ) {
    return this.wholesale.listReceivables(status);
  }

  @Post('receivables/:id/mark-paid')
  @HttpCode(HttpStatus.OK)
  markPaid(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.wholesale.markReceivablePaid(id, user.sub);
  }
}

/** The wholesale buyer's own surface — a CUSTOMER login with an active account. */
@ApiBearerAuth()
@ApiTags('wholesale')
@Controller({ path: 'wholesale', version: '1' })
@Roles(Role.CUSTOMER)
export class WholesaleController {
  constructor(private readonly wholesale: WholesaleService) {}

  @Get('access')
  access(@CurrentUser() user: AuthPrincipal) {
    return this.wholesale.access(user.sub);
  }

  @Get('catalog')
  catalog(@CurrentUser() user: AuthPrincipal) {
    return this.wholesale.catalog(user.sub);
  }

  @Post('orders')
  createOrder(@CurrentUser() user: AuthPrincipal, @Body() dto: CreateWholesaleOrderDto) {
    return this.wholesale.createOrder(user.sub, dto);
  }

  @Get('orders')
  myOrders(@CurrentUser() user: AuthPrincipal) {
    return this.wholesale.myOrders(user.sub);
  }

  @Get('receivables')
  myReceivables(@CurrentUser() user: AuthPrincipal) {
    return this.wholesale.myReceivables(user.sub);
  }
}

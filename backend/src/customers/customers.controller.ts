import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  Res,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import type { Response } from 'express';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import { CreateCustomerDto } from './dto/create-customer.dto';
import {
  AdjustPointsDto,
  BroadcastDto,
  IssueCouponDto,
  NotifyCustomerDto,
  UpdateCustomerProfileDto,
  UpdateNotesDto,
} from './dto/interactions.dto';
import { CustomersService } from './customers.service';

@ApiBearerAuth()
@ApiTags('merchant.customers')
@Controller({ path: 'merchant/customers', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
export class CustomersController {
  constructor(private readonly customers: CustomersService) {}

  /** Admin sees all customers; store staff only those they've served. */
  private scope(user: AuthPrincipal): string | null {
    if (user.role === Role.ADMIN) return null;
    if (!user.storeId) {
      throw new BadRequestException({ code: 'NO_STORE_ASSIGNED' });
    }
    return user.storeId;
  }

  @Get()
  list(
    @CurrentUser() user: AuthPrincipal,
    @Query('q') q?: string,
    @Query('page') page?: string,
    @Query('perPage') perPage?: string,
  ) {
    return this.customers.list(this.scope(user), {
      q,
      page: Number(page) || 1,
      perPage: Number(perPage) || 30,
    });
  }

  /// Export the (scoped) customer directory as a CSV download. Declared
  /// before `:id` so the literal path wins over the param route.
  @Get('export.csv')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="banan-customers.csv"')
  async exportCsv(
    @CurrentUser() user: AuthPrincipal,
    @Res() res: Response,
    @Query('q') q?: string,
  ): Promise<void> {
    const csv = await this.customers.exportCsv(this.scope(user), q);
    res.send(csv);
  }

  @Post()
  create(@CurrentUser() _user: AuthPrincipal, @Body() dto: CreateCustomerDto) {
    return this.customers.createCustomer(dto);
  }

  @Get(':id')
  detail(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.customers.detail(this.scope(user), id);
  }

  /// Edit a customer's core profile (name / phone / email / birthday).
  @Patch(':id')
  updateProfile(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: UpdateCustomerProfileDto,
  ) {
    return this.customers.updateProfile(this.scope(user), id, dto);
  }

  @Post('broadcast')
  broadcast(@CurrentUser() user: AuthPrincipal, @Body() dto: BroadcastDto) {
    return this.customers.broadcast(this.scope(user), dto.title, dto.body, dto.tag);
  }

  @Post(':id/notify')
  @HttpCode(HttpStatus.NO_CONTENT)
  async notify(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: NotifyCustomerDto,
  ): Promise<void> {
    await this.customers.notify(this.scope(user), id, dto.title, dto.body);
  }

  @Post(':id/points')
  adjustPoints(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: AdjustPointsDto,
  ) {
    return this.customers.adjustPoints(this.scope(user), id, dto.delta, dto.reason);
  }

  @Patch(':id/notes')
  updateNotes(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: UpdateNotesDto,
  ) {
    return this.customers.updateNotes(this.scope(user), id, dto.notes, dto.tags);
  }

  @Post(':id/coupon')
  issueCoupon(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: IssueCouponDto,
  ) {
    return this.customers.issueCoupon(this.scope(user), id, {
      type: dto.type,
      value: dto.value,
      minSubtotalVnd: dto.minSubtotalVnd,
      days: dto.days,
    });
  }
}

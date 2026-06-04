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
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Address, Role } from '@prisma/client';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import { CreateAddressDto, UpdateAddressDto } from './dto/address.dto';
import { AddressesService } from './addresses.service';

@ApiBearerAuth()
@ApiTags('addresses')
@Controller({ path: 'addresses', version: '1' })
@Roles(Role.CUSTOMER)
export class AddressesController {
  constructor(private readonly addresses: AddressesService) {}

  @Get()
  async list(@CurrentUser() user: AuthPrincipal) {
    const list = await this.addresses.list(user.sub);
    return list.map(AddressesController.view);
  }

  @Post()
  async create(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: CreateAddressDto,
  ) {
    return AddressesController.view(
      await this.addresses.create(user.sub, dto),
    );
  }

  @Patch(':id')
  async update(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: UpdateAddressDto,
  ) {
    return AddressesController.view(
      await this.addresses.update(user.sub, id, dto),
    );
  }

  @Post(':id/default')
  @HttpCode(HttpStatus.OK)
  async setDefault(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
  ) {
    return AddressesController.view(
      await this.addresses.setDefault(user.sub, id),
    );
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
  ): Promise<void> {
    await this.addresses.remove(user.sub, id);
  }

  private static view(a: Address) {
    return {
      id: a.id,
      label: a.label,
      recipient: a.recipient,
      phone: a.phone,
      line1: a.line1,
      line2: a.line2,
      city: a.city,
      district: a.district,
      postalCode: a.postalCode,
      isDefault: a.isDefault,
    };
  }
}

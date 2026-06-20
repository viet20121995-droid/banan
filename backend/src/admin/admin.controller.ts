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
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import { CreateKitchenDto, UpdateKitchenDto } from './dto/kitchen.dto';
import { CreateStoreDto, UpdateStoreDto } from './dto/store.dto';
import { CreateUserDto } from './dto/create-user.dto';
import { ResetUserPasswordDto } from './dto/reset-user-password.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { AdminService } from './admin.service';

@ApiBearerAuth()
@ApiTags('admin')
@Controller({ path: 'admin', version: '1' })
@Roles(Role.ADMIN)
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Post('users')
  createUser(@Body() dto: CreateUserDto) {
    return this.admin.createUser(dto);
  }

  @Get('users')
  listUsers(
    @Query('role') role?: string,
    @Query('q') q?: string,
    @Query('page') page?: string,
    @Query('perPage') perPage?: string,
  ) {
    return this.admin.listUsers({
      role,
      q,
      page: Number(page) || 1,
      perPage: Number(perPage) || 30,
    });
  }

  @Get('users/:id')
  getUser(@Param('id') id: string) {
    return this.admin.getUser(id);
  }

  @Patch('users/:id')
  updateUser(@Param('id') id: string, @Body() dto: UpdateUserDto) {
    return this.admin.updateUser(id, dto);
  }

  @Post('users/:id/reset-password')
  resetUserPassword(@Param('id') id: string, @Body() dto: ResetUserPasswordDto) {
    return this.admin.resetUserPassword(id, dto.password);
  }

  @Delete('users/:id')
  deactivateUser(@Param('id') id: string, @CurrentUser() principal: AuthPrincipal) {
    return this.admin.deactivateUser(id, principal.sub);
  }

  @Get('stores')
  stores() {
    return this.admin.listStores();
  }

  @Post('stores')
  createStore(@Body() dto: CreateStoreDto) {
    return this.admin.createStore(dto);
  }

  @Patch('stores/:id')
  updateStore(@Param('id') id: string, @Body() dto: UpdateStoreDto) {
    return this.admin.updateStore(id, dto);
  }

  @Delete('stores/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  deleteStore(@Param('id') id: string) {
    return this.admin.deleteStore(id);
  }

  @Get('kitchens')
  kitchens() {
    return this.admin.listKitchens();
  }

  @Post('kitchens')
  createKitchen(@Body() dto: CreateKitchenDto) {
    return this.admin.createKitchen(dto);
  }

  @Patch('kitchens/:id')
  updateKitchen(@Param('id') id: string, @Body() dto: UpdateKitchenDto) {
    return this.admin.updateKitchen(id, dto);
  }

  @Delete('kitchens/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  deleteKitchen(@Param('id') id: string) {
    return this.admin.deleteKitchen(id);
  }
}

import {
  Body,
  Controller,
  Get,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { Roles } from '../auth/decorators/roles.decorator';

import { CreateUserDto } from './dto/create-user.dto';
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

  @Get('stores')
  stores() {
    return this.admin.listStores();
  }

  @Get('kitchens')
  kitchens() {
    return this.admin.listKitchens();
  }
}

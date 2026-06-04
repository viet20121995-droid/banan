import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

import { Roles } from '../auth/decorators/roles.decorator';

import { NotificationsService } from './notifications.service';

class BroadcastDto {
  @IsString()
  @MinLength(3)
  @MaxLength(120)
  title!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(1000)
  body!: string;

  /// Optional deep-link target the customer app can route to on tap.
  @IsOptional()
  @IsString()
  @MaxLength(200)
  linkPath?: string;
}

@ApiBearerAuth()
@ApiTags('merchant.broadcast')
@Controller({ path: 'merchant/broadcast', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.ADMIN)
export class BroadcastController {
  constructor(private readonly notifications: NotificationsService) {}

  /// Push an in-app campaign notification to every customer's inbox.
  @Post()
  @HttpCode(HttpStatus.OK)
  async broadcast(@Body() dto: BroadcastDto) {
    return this.notifications.broadcastToCustomers(
      { type: 'campaign', title: dto.title, body: dto.body },
      dto.linkPath ? { linkPath: dto.linkPath } : undefined,
    );
  }
}

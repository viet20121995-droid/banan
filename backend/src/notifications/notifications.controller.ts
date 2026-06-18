import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsString } from 'class-validator';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import { NotificationsService } from './notifications.service';

class MarkReadDto {
  @IsArray()
  @ArrayMaxSize(200)
  @IsString({ each: true })
  ids!: string[];
}

@ApiBearerAuth()
@ApiTags('notifications')
@Controller({ path: 'me/notifications', version: '1' })
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  list(
    @CurrentUser() user: AuthPrincipal,
    @Query('page') page?: string,
    @Query('perPage') perPage?: string,
  ) {
    // Clamp + floor pagination — an authenticated user could otherwise request
    // a huge perPage (unbounded read) or a decimal/Infinity (Prisma `take`
    // must be an integer, else 500).
    return this.notifications.listForUser(
      user.sub,
      Math.max(Math.floor(Number(page)) || 1, 1),
      Math.min(Math.max(Math.floor(Number(perPage)) || 30, 1), 100),
    );
  }

  @Post('read')
  @HttpCode(HttpStatus.NO_CONTENT)
  async markRead(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: MarkReadDto,
  ): Promise<void> {
    await this.notifications.markRead(user.sub, dto.ids);
  }

  @Post('read-all')
  @HttpCode(HttpStatus.NO_CONTENT)
  async markAllRead(@CurrentUser() user: AuthPrincipal): Promise<void> {
    await this.notifications.markAllRead(user.sub);
  }
}

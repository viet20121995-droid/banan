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
import { PaginationDto } from '../common/dto/pagination.dto';

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
  list(@CurrentUser() user: AuthPrincipal, @Query() q: PaginationDto) {
    // PaginationDto validates page/perPage as finite ints (1..100) at the
    // boundary, so a decimal/Infinity is rejected with 400 rather than
    // reaching Prisma and 500-ing.
    return this.notifications.listForUser(user.sub, q.page ?? 1, q.perPage ?? 30);
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

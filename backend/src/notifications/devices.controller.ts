import {
  Body,
  Controller,
  Delete,
  HttpCode,
  HttpStatus,
  Param,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { DevicePlatform } from '@prisma/client';
import {
  IsEnum,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';
import { PrismaService } from '../prisma/prisma.service';

class RegisterDeviceDto {
  @IsEnum(DevicePlatform)
  platform!: DevicePlatform;

  @IsString()
  @MinLength(8)
  @MaxLength(4096)
  token!: string;
}

@ApiBearerAuth()
@ApiTags('me.devices')
@Controller({ path: 'me/devices', version: '1' })
export class MeDevicesController {
  constructor(private readonly prisma: PrismaService) {}

  /** Idempotent registration — the same token from a previously-logged-in
   *  user gets re-pointed to the current user. */
  @Post()
  async register(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: RegisterDeviceDto,
  ) {
    const now = new Date();
    const device = await this.prisma.deviceToken.upsert({
      where: { token: dto.token },
      create: {
        userId: user.sub,
        platform: dto.platform,
        token: dto.token,
        lastSeen: now,
      },
      update: {
        userId: user.sub,
        platform: dto.platform,
        lastSeen: now,
      },
    });
    return { id: device.id };
  }

  @Delete(':token')
  @HttpCode(HttpStatus.NO_CONTENT)
  async unregister(
    @CurrentUser() user: AuthPrincipal,
    @Param('token') token: string,
  ): Promise<void> {
    await this.prisma.deviceToken.deleteMany({
      where: { token, userId: user.sub },
    });
  }
}

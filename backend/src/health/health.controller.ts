import { Controller, Get } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiTags } from '@nestjs/swagger';

import { Public } from '../auth/decorators/public.decorator';
import { PrismaService } from '../prisma/prisma.service';

@ApiTags('health')
@Public()
@Controller({ path: 'health', version: '1' })
export class HealthController {
  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  /** Liveness + DB ping. Used by the Flutter splash and infra checks. */
  @Get()
  async check() {
    let dbOk = false;
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      dbOk = true;
    } catch {
      dbOk = false;
    }
    return {
      ok: dbOk,
      environment: this.config.get<string>('NODE_ENV') ?? 'development',
      timestamp: new Date().toISOString(),
    };
  }
}

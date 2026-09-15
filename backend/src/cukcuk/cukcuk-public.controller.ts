import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';

import { Public } from '../auth/decorators/public.decorator';

import { normalizePhone } from './cukcuk-normalize';
import { CukcukService } from './cukcuk.service';

/**
 * Customer-site "Tra cứu chi tiêu": a guest types their phone and sees the
 * spend CukCuk recorded at the counter, the Micho it converts to and whether
 * the 5% member discount applies. Deliberately coarse — totals only, masked
 * name, no invoices — and throttled, since the phone is the only key.
 */
@ApiTags('public.spend-lookup')
@Controller({ path: 'public/spend-lookup', version: '1' })
export class CukcukPublicController {
  constructor(private readonly cukcuk: CukcukService) {}

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Get()
  lookup(@Query('phone') phone?: string) {
    const normalized = normalizePhone(phone);
    if (!normalized) {
      throw new BadRequestException({
        code: 'PHONE_INVALID',
        message: 'Số điện thoại không hợp lệ.',
      });
    }
    return this.cukcuk.lookupByPhone(normalized);
  }
}

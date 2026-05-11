import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import { LoyaltyService } from './loyalty.service';

@ApiBearerAuth()
@ApiTags('loyalty')
@Controller({ path: 'me/loyalty', version: '1' })
export class LoyaltyController {
  constructor(private readonly loyalty: LoyaltyService) {}

  @Get()
  me(@CurrentUser() user: AuthPrincipal) {
    return this.loyalty.getMyLoyalty(user.sub);
  }
}

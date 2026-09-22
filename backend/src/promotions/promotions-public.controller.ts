import { Body, Controller, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Public } from '../auth/decorators/public.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';
import { PrismaService } from '../prisma/prisma.service';

import { QuotePromotionsDto } from './dto';
import { PromotionsService } from './promotions.service';

/**
 * Checkout preview of the automatic campaign engine. Same evaluation the
 * order transaction runs, so the total the customer sees is the total they
 * are charged. Line totals come from the client — this is a preview only;
 * `OrdersService.create` re-prices everything authoritatively.
 */
@ApiTags('promotions')
@Controller({ path: 'promotions', version: '1' })
export class PromotionsPublicController {
  constructor(
    private readonly promotions: PromotionsService,
    private readonly prisma: PrismaService,
  ) {}

  @Public()
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Post('quote')
  async quote(@CurrentUser() user: AuthPrincipal | null, @Body() dto: QuotePromotionsDto) {
    // Mirror the order path for guests: a known CUSTOMER phone is bound to
    // that account with no customer campaigns; anything else is a new customer.
    let newCustomer = false;
    if (!user) {
      const phone = dto.guestPhone?.trim();
      const existing = phone
        ? await this.prisma.user.findUnique({ where: { phone }, select: { role: true } })
        : null;
      newCustomer = !existing || existing.role !== 'CUSTOMER';
    }
    return this.promotions.evaluate({
      lines: dto.lines.map((l) => ({
        productId: l.productId,
        quantity: l.quantity,
        lineTotalVnd: l.lineTotalVnd,
        comboLine: l.comboLine ?? false,
      })),
      storeId: dto.storeId,
      subtotalVnd: dto.subtotalVnd,
      customerId: user?.sub,
      newCustomer,
    });
  }
}

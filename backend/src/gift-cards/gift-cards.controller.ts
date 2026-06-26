import { Body, Controller, Get, HttpCode, HttpStatus, Param, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import { IssueGiftCardDto, ValidateGiftCardDto } from './dto';
import { GiftCardsService } from './gift-cards.service';

@ApiTags('gift-cards')
@Controller({ path: 'gift-cards', version: '1' })
export class GiftCardsController {
  constructor(private readonly cards: GiftCardsService) {}

  /// Public — customer checks a code before applying it at checkout.
  @Public()
  @Post('validate')
  @HttpCode(HttpStatus.OK)
  validate(@Body() dto: ValidateGiftCardDto) {
    return this.cards.validate(dto.code);
  }
}

@ApiBearerAuth()
@ApiTags('merchant.gift-cards')
@Controller({ path: 'merchant/gift-cards', version: '1' })
@Roles(Role.ADMIN, Role.MERCHANT_OWNER)
export class MerchantGiftCardsController {
  constructor(private readonly cards: GiftCardsService) {}

  @Get()
  list(@CurrentUser() user: AuthPrincipal) {
    return this.cards.list(user);
  }

  @Post()
  issue(@CurrentUser() user: AuthPrincipal, @Body() dto: IssueGiftCardDto) {
    return this.cards.issue({
      valueVnd: dto.valueVnd,
      expiresAt: dto.expiresAt,
      note: dto.note,
      issuedById: user.sub,
    });
  }

  @Patch(':id/deactivate')
  @HttpCode(HttpStatus.OK)
  deactivate(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.cards.deactivate(id, user);
  }
}

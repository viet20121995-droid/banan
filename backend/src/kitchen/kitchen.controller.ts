import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsEnum } from 'class-validator';
import { KitchenStatus, Role } from '@prisma/client';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';
import { OrdersService } from '../orders/orders.service';

class KitchenTransitionDto {
  @IsEnum(KitchenStatus)
  toKitchenStatus!: KitchenStatus;
}

@ApiBearerAuth()
@ApiTags('kitchen')
@Controller({ path: 'kitchen/orders', version: '1' })
@Roles(Role.KITCHEN_MANAGER, Role.KITCHEN_STAFF, Role.ADMIN)
export class KitchenController {
  constructor(private readonly orders: OrdersService) {}

  /**
   * Kanban list of orders routed to this kitchen and not yet dispatched.
   * Optional `?kitchenStatus=BAKING` filter for column-specific polling.
   */
  @Get()
  list(
    @CurrentUser() user: AuthPrincipal,
    @Query('kitchenStatus') kitchenStatus?: KitchenStatus,
  ) {
    if (!user.kitchenId && user.role !== Role.ADMIN) {
      throw new BadRequestException({ code: 'NO_KITCHEN_ASSIGNED' });
    }
    return this.orders.listForKitchen(user.kitchenId!, { status: kitchenStatus });
  }

  @Get(':id')
  findOne(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.orders.findOne(id, user);
  }

  /** Walk forward through the kanban states. */
  @Post(':id/transition')
  @HttpCode(HttpStatus.OK)
  transition(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: KitchenTransitionDto,
  ) {
    return this.orders.transitionKitchen(id, dto.toKitchenStatus, user);
  }

  /** Hand the order back to the store for pickup or delivery. */
  @Post(':id/dispatch')
  @HttpCode(HttpStatus.OK)
  dispatch(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.orders.dispatchFromKitchen(id, user);
  }
}

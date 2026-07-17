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
   * Optional `?kitchenStatus=PREPARING` filter for column-specific polling.
   * Pass `?includeDoneToday=1` to also surface today's dispatched orders
   * so the kanban can show a "Completed" column.
   */
  @Get()
  list(
    @CurrentUser() user: AuthPrincipal,
    @Query('kitchenStatus') kitchenStatus?: KitchenStatus,
    @Query('includeDoneToday') includeDoneToday?: string,
    @Query('kitchenId') kitchenIdParam?: string,
  ) {
    // KITCHEN_* users are scoped to their own kitchen (from the JWT) and cannot
    // override it. An ADMIN has no kitchen, so they MUST pass ?kitchenId= to
    // pick a queue — otherwise listForKitchen(null) would query
    // `WHERE kitchenId IS NULL` and surface UNROUTED orders instead of a real
    // kitchen's kanban (mirrors the admin ?kitchenId= rule in analytics).
    const kitchenId = user.kitchenId ?? (user.role === Role.ADMIN ? kitchenIdParam : undefined);
    if (!kitchenId) {
      throw new BadRequestException({ code: 'NO_KITCHEN_ASSIGNED' });
    }
    return this.orders.listForKitchen(kitchenId, {
      status: kitchenStatus,
      includeDoneToday: includeDoneToday === '1' || includeDoneToday === 'true',
    });
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

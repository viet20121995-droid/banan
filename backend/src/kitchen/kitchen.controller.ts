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
  Res,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { KitchenStatus, Role } from '@prisma/client';
import type { Response } from 'express';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';
import { OrdersService } from '../orders/orders.service';

import { isKitchenDate } from './kitchen-queue-where';
import { renderTransferSheetPdf, transferDayLabel } from './transfer-sheet-pdf';

class KitchenTransitionDto {
  @IsEnum(KitchenStatus)
  toKitchenStatus!: KitchenStatus;
}

class AdjustItemDto {
  @IsUUID()
  orderItemId!: string;

  @IsInt()
  @Min(0)
  quantity!: number;
}

class AdjustMfgItemDto {
  @IsUUID()
  itemId!: string;

  @IsNumber()
  @Min(0)
  qty!: number;
}

/** Kitchen edits the quantities that will actually ship on a transfer. */
class SheetLineDto {
  @IsUUID()
  orderId!: string;

  @IsUUID()
  itemId!: string;

  @IsEnum(['item', 'mfg'])
  kind!: 'item' | 'mfg';

  @IsNumber()
  @Min(0)
  qty!: number;
}

/** The kitchen's edits on the order sheet — every cell that changed. */
class SaveSheetDto {
  @IsArray()
  @ArrayMaxSize(400)
  @ValidateNested({ each: true })
  @Type(() => SheetLineDto)
  lines!: SheetLineDto[];
}

class DispatchDayDto {
  @IsString()
  day!: string;
}

class AdjustTransferDto {
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(40)
  @ValidateNested({ each: true })
  @Type(() => AdjustItemDto)
  items?: AdjustItemDto[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(40)
  @ValidateNested({ each: true })
  @Type(() => AdjustMfgItemDto)
  mfgItems?: AdjustMfgItemDto[];

  @IsOptional()
  @IsString()
  @MaxLength(280)
  note?: string;
}

@ApiBearerAuth()
@ApiTags('kitchen')
@Controller({ path: 'kitchen/orders', version: '1' })
@Roles(Role.KITCHEN_MANAGER, Role.KITCHEN_STAFF, Role.ADMIN)
export class KitchenController {
  constructor(private readonly orders: OrdersService) {}

  /**
   * Kitchen board list. Default: orders routed to this kitchen and not yet
   * dispatched; `?kitchenStatus=PREPARING` narrows to one stage;
   * `?includeDoneToday=1` also surfaces today's dispatched orders.
   * `?date=yyyy-MM-dd` or `?from=&to=` (VN calendar days, inclusive) returns
   * the board keyed on the day orders have to be READY — past days or
   * orders scheduled ahead; a range covering today also keeps overdue /
   * unscheduled live work. See `kitchenQueueWhere`.
   */
  @Get()
  list(
    @CurrentUser() user: AuthPrincipal,
    @Query('kitchenStatus') kitchenStatus?: KitchenStatus,
    @Query('includeDoneToday') includeDoneToday?: string,
    @Query('kitchenId') kitchenIdParam?: string,
    @Query('date') date?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    for (const [name, value] of [
      ['date', date],
      ['from', from],
      ['to', to],
    ] as const) {
      if (value !== undefined && !isKitchenDate(value)) {
        throw new BadRequestException({
          code: 'INVALID_DATE',
          message: `${name} phải là yyyy-MM-dd`,
        });
      }
    }
    if (from && to && from > to) {
      throw new BadRequestException({ code: 'INVALID_DATE', message: 'from phải ≤ to' });
    }
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
      date,
      from,
      to,
    });
  }

  private kitchenOf(user: AuthPrincipal, kitchenIdParam?: string): string {
    const kitchenId = user.kitchenId ?? (user.role === Role.ADMIN ? kitchenIdParam : undefined);
    if (!kitchenId) throw new BadRequestException({ code: 'NO_KITCHEN_ASSIGNED' });
    return kitchenId;
  }

  /**
   * The branch order book as the kitchen works it: every live internal
   * transfer, one sheet per delivery day, per branch ordered vs shipped.
   * Declared before ':id' routes out of caution, though the path depth
   * already differs.
   */
  @Get('internal-transfer/sheet')
  transferSheet(@CurrentUser() user: AuthPrincipal, @Query('kitchenId') kitchenIdParam?: string) {
    return this.orders.internalTransferSheet(this.kitchenOf(user, kitchenIdParam));
  }

  /** Save the "Giao" cells the kitchen edited on the sheet. */
  @Post('internal-transfer/sheet/save')
  @HttpCode(HttpStatus.OK)
  saveTransferSheet(@CurrentUser() user: AuthPrincipal, @Body() dto: SaveSheetDto) {
    return this.orders.saveTransferSheet(user, dto.lines);
  }

  /** "Xuất đi cả ngày": dispatch every live transfer due on `day`. */
  @Post('internal-transfer/sheet/dispatch')
  @HttpCode(HttpStatus.OK)
  dispatchTransferDay(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: DispatchDayDto,
    @Query('kitchenId') kitchenIdParam?: string,
  ) {
    if (!isKitchenDate(dto.day)) {
      throw new BadRequestException({ code: 'INVALID_DAY', message: 'day phải là yyyy-MM-dd' });
    }
    return this.orders.dispatchTransferDay(this.kitchenOf(user, kitchenIdParam), user, dto.day);
  }

  /** The sheet for one day as a printable PDF (landscape A4). */
  @Get('internal-transfer/sheet/pdf')
  async transferSheetPdf(
    @CurrentUser() user: AuthPrincipal,
    @Query('day') day: string,
    @Res() res: Response,
    @Query('kitchenId') kitchenIdParam?: string,
  ) {
    if (!day || !isKitchenDate(day)) {
      throw new BadRequestException({ code: 'INVALID_DAY', message: 'day phải là yyyy-MM-dd' });
    }
    const sheet = await this.orders.internalTransferSheet(this.kitchenOf(user, kitchenIdParam));
    const one = sheet.days.find((d) => d.day === day) ?? { day, orders: [], stores: [], rows: [] };
    const bytes = await renderTransferSheetPdf(one);
    res
      .status(200)
      .setHeader('Content-Type', 'application/pdf')
      .setHeader(
        'Content-Disposition',
        `inline; filename="phieu-dat-hang-${day}.pdf"; filename*=UTF-8''${encodeURIComponent(
          `Phiếu đặt hàng ${transferDayLabel(day)}.pdf`,
        )}`,
      )
      .send(bytes);
  }

  @Get(':id')
  findOne(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.orders.findOne(id, user);
  }

  /** Adjust shipped quantities on an internal transfer (shortage/breakage). */
  @Post(':id/adjust-transfer')
  @HttpCode(HttpStatus.OK)
  adjustTransfer(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: AdjustTransferDto,
  ) {
    return this.orders.adjustInternalTransfer(id, user, dto);
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

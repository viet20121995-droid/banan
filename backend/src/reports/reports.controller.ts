import {
  Controller,
  Get,
  Query,
  Res,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { OrderStatus, Role } from '@prisma/client';
import type { Response } from 'express';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import { ReportsService } from './reports.service';

@ApiBearerAuth()
@ApiTags('merchant.reports')
@Controller({ path: 'merchant/reports', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  /// Scope every request to the merchant's store. Admin sees chain-wide
  /// (storeId omitted) unless they explicitly filter `?storeId=`.
  private rangeOf(
    user: AuthPrincipal,
    q: { from?: string; to?: string; storeId?: string },
  ) {
    const scopedStore =
      user.role === Role.ADMIN
        ? q.storeId
        : user.storeId ?? undefined;
    return this.reports.parseRange({ ...q, storeId: scopedStore });
  }

  @Get('summary')
  summary(
    @CurrentUser() user: AuthPrincipal,
    @Query() q: { from?: string; to?: string; storeId?: string },
  ) {
    return this.reports.summary(this.rangeOf(user, q));
  }

  @Get('products')
  products(
    @CurrentUser() user: AuthPrincipal,
    @Query() q: { from?: string; to?: string; storeId?: string; limit?: string },
  ) {
    return this.reports.productSales(
      this.rangeOf(user, q),
      Number(q.limit) || 50,
    );
  }

  @Get('orders')
  orders(
    @CurrentUser() user: AuthPrincipal,
    @Query()
    q: { from?: string; to?: string; storeId?: string; status?: OrderStatus },
  ) {
    return this.reports.orderRows(this.rangeOf(user, q), q.status);
  }

  @Get('refunds')
  refunds(
    @CurrentUser() user: AuthPrincipal,
    @Query() q: { from?: string; to?: string; storeId?: string },
  ) {
    return this.reports.refundRows(this.rangeOf(user, q));
  }

  /// XLSX export — single multi-sheet workbook with every report for the
  /// chosen period. Set as a file download via Content-Disposition.
  @Get('export.xlsx')
  async exportXlsx(
    @CurrentUser() user: AuthPrincipal,
    @Query() q: { from?: string; to?: string; storeId?: string },
    @Res() res: Response,
  ): Promise<void> {
    const range = this.rangeOf(user, q);
    const buf = await this.reports.buildWorkbook(range);
    const filename = `banan-report-${q.from}_${q.to}.xlsx`;
    res.set({
      'Content-Type':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="${filename}"`,
      'Content-Length': buf.length.toString(),
    });
    res.end(buf);
  }
}

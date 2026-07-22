import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';

import {
  CompleteMaintenanceDto,
  CreateBomDto,
  CreateMaintenanceDto,
  CreateMoDto,
  CreatePoDto,
  CreateProductDto,
  CreateQualityPointDto,
  CreateSupplierDto,
  PlanMoDto,
  ReceiveDto,
  RecordCheckDto,
  ScrapDto,
  SetAlertStageDto,
  UpdatePoDto,
  UpdateProductDto,
  UpdateSupplierDto,
} from './dto/manufacturing.dto';
import { ManufacturingService } from './manufacturing.service';

/**
 * Kitchen MES — the "Sản xuất" section. Separate from the ordering/kitchen-queue
 * endpoints. Reads are open to any kitchen role; anything that moves stock or
 * cost is manager/admin only. Finer roles (baker start/done, QC, warehouse)
 * arrive with the shop-floor increment.
 */
const KITCHEN_READ = [Role.KITCHEN_MANAGER, Role.KITCHEN_STAFF, Role.ADMIN];
const KITCHEN_WRITE = [Role.KITCHEN_MANAGER, Role.ADMIN];
// Shop-floor actions (start/done a work order, record a QC check) are the
// baker's/QC's daily job, so staff may do them too.
const KITCHEN_FLOOR = [Role.KITCHEN_MANAGER, Role.KITCHEN_STAFF, Role.ADMIN];

@ApiTags('manufacturing')
@Controller({ path: 'manufacturing', version: '1' })
export class ManufacturingController {
  constructor(private readonly mfg: ManufacturingService) {}

  // ── master data (for the Sản xuất UI) ────────────────────────────────────
  @Roles(...KITCHEN_READ)
  @Get('products')
  listProducts(@Query('type') type?: string, @Query('all') all?: string) {
    return this.mfg.listProducts(type, all === '1');
  }

  @Roles(...KITCHEN_WRITE)
  @Post('products')
  createProduct(@Body() dto: CreateProductDto) {
    return this.mfg.createProduct(dto);
  }

  @Roles(...KITCHEN_WRITE)
  @Patch('products/:id')
  updateProduct(@Param('id') id: string, @Body() dto: UpdateProductDto) {
    return this.mfg.updateProduct(id, dto);
  }

  @Roles(...KITCHEN_READ)
  @Get('categories')
  listCategories() {
    return this.mfg.listCategories();
  }

  @Roles(...KITCHEN_READ)
  @Get('uoms')
  listUoms() {
    return this.mfg.listUoms();
  }

  @Roles(...KITCHEN_READ)
  @Get('boms')
  listBoms() {
    return this.mfg.listBoms();
  }

  @Roles(...KITCHEN_READ)
  @Get('boms/:id')
  getBom(@Param('id') id: string) {
    return this.mfg.getBom(id);
  }

  @Roles(...KITCHEN_WRITE)
  @Post('boms')
  createBom(@Body() dto: CreateBomDto) {
    return this.mfg.createBom(dto);
  }

  @Roles(...KITCHEN_READ)
  @Get('work-centers')
  listWorkCenters() {
    return this.mfg.listWorkCenters();
  }

  @Roles(...KITCHEN_READ)
  @Get('dashboard/mo-counts')
  moCounts() {
    return this.mfg.moStateCounts();
  }

  // ── reports + replenishment ───────────────────────────────────────────────
  @Roles(...KITCHEN_READ)
  @Get('reports/production')
  productionReport(@Query('from') from?: string, @Query('to') to?: string) {
    return this.mfg.productionReport(from, to);
  }

  @Roles(...KITCHEN_READ)
  @Get('reports/scrap')
  scrapReport(@Query('from') from?: string, @Query('to') to?: string) {
    return this.mfg.scrapReport(from, to);
  }

  @Roles(...KITCHEN_READ)
  @Get('reports/cost')
  costReport(@Query('from') from?: string, @Query('to') to?: string) {
    return this.mfg.costReport(from, to);
  }

  @Roles(...KITCHEN_READ)
  @Get('replenishment')
  replenishment() {
    return this.mfg.replenishment();
  }

  @Roles(...KITCHEN_READ)
  @Get('reports/oee')
  oeeReport(@Query('from') from?: string, @Query('to') to?: string) {
    return this.mfg.oeeReport(from, to);
  }

  // ── maintenance ───────────────────────────────────────────────────────────
  @Roles(...KITCHEN_READ)
  @Get('maintenance')
  listMaintenance(@Query('state') state?: string) {
    return this.mfg.listMaintenance(state);
  }

  @Roles(...KITCHEN_WRITE)
  @Post('maintenance')
  createMaintenance(@Body() dto: CreateMaintenanceDto) {
    return this.mfg.createMaintenance(dto);
  }

  @Roles(...KITCHEN_WRITE)
  @HttpCode(HttpStatus.OK)
  @Post('maintenance/:id/complete')
  completeMaintenance(@Param('id') id: string, @Body() dto: CompleteMaintenanceDto) {
    return this.mfg.completeMaintenance(id, dto);
  }

  // ── planning (schedule + employee assignment) ─────────────────────────────
  @Roles(...KITCHEN_READ)
  @Get('staff')
  listStaff() {
    return this.mfg.listStaff();
  }

  @Roles(...KITCHEN_READ)
  @Get('schedule')
  schedule() {
    return this.mfg.schedule();
  }

  @Roles(...KITCHEN_WRITE)
  @HttpCode(HttpStatus.OK)
  @Post('orders/:id/plan')
  planMO(@Param('id') id: string, @Body() dto: PlanMoDto) {
    return this.mfg.planMO(id, dto);
  }

  // ── costing ────────────────────────────────────────────────────────────
  @Roles(...KITCHEN_READ)
  @Get('boms/:id/cost')
  bomCost(@Param('id') id: string) {
    return this.mfg.bomCost(id);
  }

  // ── manufacturing orders ─────────────────────────────────────────────────
  @Roles(...KITCHEN_READ)
  @Get('orders')
  listMOs(@Query('state') state?: string) {
    return this.mfg.listMOs(state);
  }

  @Roles(...KITCHEN_READ)
  @Get('orders/:id')
  getMO(@Param('id') id: string) {
    return this.mfg.getMO(id);
  }

  @Roles(...KITCHEN_WRITE)
  @Post('orders')
  createMO(@Body() dto: CreateMoDto) {
    return this.mfg.createMO(dto);
  }

  @Roles(...KITCHEN_WRITE)
  @Post('orders/:id/confirm')
  confirmMO(@Param('id') id: string) {
    return this.mfg.confirmMO(id);
  }

  @Roles(...KITCHEN_READ)
  @Get('orders/:id/check-availability')
  checkAvailability(@Param('id') id: string) {
    return this.mfg.checkAvailability(id);
  }

  @Roles(...KITCHEN_WRITE)
  @Post('orders/:id/reserve')
  reserve(@Param('id') id: string) {
    return this.mfg.reserve(id);
  }

  @Roles(...KITCHEN_WRITE)
  @Post('orders/:id/produce')
  produce(@Param('id') id: string) {
    return this.mfg.produce(id);
  }

  @Roles(...KITCHEN_WRITE)
  @HttpCode(HttpStatus.OK)
  @Post('orders/:id/cancel')
  cancelMO(@Param('id') id: string) {
    return this.mfg.cancelMO(id);
  }

  // ── purchasing (suppliers + POs + history) ───────────────────────────────
  @Roles(...KITCHEN_READ)
  @Get('suppliers')
  listSuppliers(@Query('all') all?: string) {
    return this.mfg.listSuppliers(all === '1');
  }

  @Roles(...KITCHEN_WRITE)
  @Post('suppliers')
  createSupplier(@Body() dto: CreateSupplierDto) {
    return this.mfg.createSupplier(dto);
  }

  @Roles(...KITCHEN_WRITE)
  @Patch('suppliers/:id')
  updateSupplier(@Param('id') id: string, @Body() dto: UpdateSupplierDto) {
    return this.mfg.updateSupplier(id, dto);
  }

  @Roles(...KITCHEN_READ)
  @Get('purchase-orders')
  listPurchaseOrders(@Query('state') state?: string) {
    return this.mfg.listPurchaseOrders(state);
  }

  @Roles(...KITCHEN_READ)
  @Get('purchase-orders/:id')
  getPurchaseOrder(@Param('id') id: string) {
    return this.mfg.getPurchaseOrder(id);
  }

  @Roles(...KITCHEN_WRITE)
  @Post('purchase-orders')
  createPurchaseOrder(@Body() dto: CreatePoDto, @CurrentUser() user: AuthPrincipal) {
    return this.mfg.createPurchaseOrder(dto, user.sub);
  }

  @Roles(...KITCHEN_WRITE)
  @Patch('purchase-orders/:id')
  updatePurchaseOrder(@Param('id') id: string, @Body() dto: UpdatePoDto) {
    return this.mfg.updatePurchaseOrder(id, dto);
  }

  @Roles(...KITCHEN_WRITE)
  @HttpCode(HttpStatus.OK)
  @Post('purchase-orders/:id/confirm')
  confirmPurchaseOrder(@Param('id') id: string) {
    return this.mfg.confirmPurchaseOrder(id);
  }

  @Roles(...KITCHEN_WRITE)
  @HttpCode(HttpStatus.OK)
  @Post('purchase-orders/:id/cancel')
  cancelPurchaseOrder(@Param('id') id: string) {
    return this.mfg.cancelPurchaseOrder(id);
  }

  @Roles(...KITCHEN_READ)
  @Get('products/:id/purchase-history')
  purchaseHistory(@Param('id') id: string) {
    return this.mfg.purchaseHistory(id);
  }

  // ── stock ────────────────────────────────────────────────────────────────
  @Roles(...KITCHEN_WRITE)
  @Post('receipts')
  receive(@Body() dto: ReceiveDto) {
    return this.mfg.receive(dto);
  }

  @Roles(...KITCHEN_WRITE)
  @Post('scraps')
  scrap(@Body() dto: ScrapDto) {
    return this.mfg.scrap(dto);
  }

  @Roles(...KITCHEN_READ)
  @Get('stock/on-hand')
  onHand(@Query('productId') productId?: string) {
    return this.mfg.onHand(productId);
  }

  @Roles(...KITCHEN_READ)
  @Get('lots/expiring')
  expiring(@Query('before') before: string) {
    return this.mfg.expiringLots(before);
  }

  @Roles(...KITCHEN_READ)
  @Get('traceability/lot/:id')
  trace(@Param('id') id: string) {
    return this.mfg.traceLot(id);
  }

  // ── shop floor + QC ───────────────────────────────────────────────────────
  @Roles(...KITCHEN_READ)
  @Get('shop-floor')
  shopFloor(@Query('workCenter') workCenter?: string) {
    return this.mfg.shopFloor(workCenter);
  }

  @Roles(...KITCHEN_FLOOR)
  @Post('work-orders/:id/start')
  startWo(@Param('id') id: string) {
    return this.mfg.startWO(id);
  }

  @Roles(...KITCHEN_FLOOR)
  @Post('work-orders/:id/pause')
  pauseWo(@Param('id') id: string) {
    return this.mfg.pauseWO(id);
  }

  @Roles(...KITCHEN_FLOOR)
  @Post('work-orders/:id/done')
  doneWo(@Param('id') id: string) {
    return this.mfg.doneWO(id);
  }

  @Roles(...KITCHEN_READ)
  @Get('quality-points')
  listQualityPoints(@Query('bomOperationId') bomOperationId?: string) {
    return this.mfg.listQualityPoints(bomOperationId);
  }

  @Roles(...KITCHEN_WRITE)
  @Post('quality-points')
  createQualityPoint(@Body() dto: CreateQualityPointDto) {
    return this.mfg.createQualityPoint(dto);
  }

  @Roles(...KITCHEN_FLOOR)
  @Post('quality-checks')
  recordCheck(@Body() dto: RecordCheckDto, @CurrentUser() user: AuthPrincipal) {
    return this.mfg.recordCheck({ ...dto, userId: user.sub });
  }

  @Roles(...KITCHEN_READ)
  @Get('quality-alerts')
  listAlerts(@Query('stage') stage?: string) {
    return this.mfg.listAlerts(stage);
  }

  @Roles(...KITCHEN_WRITE)
  @Post('quality-alerts/:id/stage')
  setAlertStage(@Param('id') id: string, @Body() dto: SetAlertStageDto) {
    return this.mfg.setAlertStage(id, dto.stage);
  }
}

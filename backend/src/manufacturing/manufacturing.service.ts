import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import type {
  BomLineInput,
  BomOperationInput,
  CreatePoDto,
  CreateSupplierDto,
  UpdatePoDto,
  UpdateSupplierDto,
} from './dto/manufacturing.dto';
import {
  avcoAfterReceipt,
  expiryDate,
  round3,
  roundCost,
  roundMoney,
  toBase,
  type UomLike,
} from './mfg-math';

/** Prisma.Decimal → number at the service boundary. */
const n = (d: Prisma.Decimal | number | null | undefined): number => (d == null ? 0 : Number(d));

/** A Prisma UoM row reduced to what mfg-math needs (Decimal factor → number). */
const uomLike = (u: { category: string; factor: Prisma.Decimal }): UomLike => ({
  category: u.category,
  factor: Number(u.factor),
});

type Tx = Prisma.TransactionClient;

/**
 * The manufacturing engine. Everything that changes stock or cost runs inside a
 * transaction so a half-finished produce can never leave quants and lots out of
 * sync. Pure arithmetic lives in mfg-math; this file is the orchestration and
 * the Prisma I/O around it.
 *
 * Stock lives at two well-known locations resolved by code: STOCK (on-hand) and
 * SCRAP. PRODUCTION is the virtual location components flow through on their way
 * into a finished good — the move pair (STOCK→PRODUCTION out, PRODUCTION→STOCK
 * in) is what makes a lot traceable back to what it consumed.
 */
@Injectable()
export class ManufacturingService {
  constructor(private readonly prisma: PrismaService) {}

  // ── locations ────────────────────────────────────────────────────────────

  private async locationId(db: Tx | PrismaService, code: string): Promise<string> {
    const loc = await db.mfgLocation.findUnique({ where: { code } });
    if (!loc) {
      throw new BadRequestException({
        code: 'MFG_LOCATION_MISSING',
        message: `Chưa cấu hình location "${code}". Chạy seed trước.`,
      });
    }
    return loc.id;
  }

  // ── stock primitives ─────────────────────────────────────────────────────

  /** Upsert a quant and shift its on-hand / reserved by the given deltas. */
  private async adjustQuant(
    db: Tx,
    args: {
      productId: string;
      lotId: string | null;
      locationId: string;
      dQty?: number;
      dReserved?: number;
    },
  ): Promise<void> {
    // findFirst, not findUnique: the compound key includes a nullable lotId,
    // and Prisma's WhereUniqueInput doesn't accept null in a compound. Equality
    // on the three fields is unambiguous because of the @@unique.
    // ponytail: a concurrent FIRST-TOUCH of the same (product, null-lot,
    // location) can race two callers past this findFirst into two create()s — a
    // duplicate quant row. Harmless to totals (availableAtStock SUMs every
    // matching quant); if it ever matters, add a NULLS NOT DISTINCT unique +
    // an ON CONFLICT upsert.
    const existing = await db.mfgStockQuant.findFirst({
      where: {
        productId: args.productId,
        lotId: args.lotId,
        locationId: args.locationId,
      },
    });
    if (existing) {
      // Atomic increment, not read-modify-write: Postgres row-locks the UPDATE,
      // so two concurrent moves against the same quant both apply instead of one
      // clobbering the other. Deltas are pre-rounded and the column is
      // Decimal(14,3), so accumulation stays exact.
      await db.mfgStockQuant.update({
        where: { id: existing.id },
        data: {
          quantity: { increment: round3(args.dQty ?? 0) },
          reservedQty: { increment: round3(args.dReserved ?? 0) },
        },
      });
    } else {
      await db.mfgStockQuant.create({
        data: {
          productId: args.productId,
          lotId: args.lotId,
          locationId: args.locationId,
          quantity: round3(args.dQty ?? 0),
          reservedQty: round3(args.dReserved ?? 0),
        },
      });
    }
  }

  /** Record a move and shift both endpoints' on-hand. */
  private async move(
    db: Tx,
    args: {
      productId: string;
      lotId: string | null;
      qty: number; // in the product's base unit
      uomId: string;
      srcLocationId: string;
      destLocationId: string;
      refType: 'RECEIPT' | 'DELIVERY' | 'INTERNAL' | 'MO' | 'SCRAP';
      refId?: string;
      unitCost?: number;
    },
  ): Promise<void> {
    await db.mfgStockMove.create({
      data: {
        productId: args.productId,
        lotId: args.lotId,
        qty: round3(args.qty),
        uomId: args.uomId,
        srcLocationId: args.srcLocationId,
        destLocationId: args.destLocationId,
        refType: args.refType,
        refId: args.refId,
        unitCost: roundCost(args.unitCost ?? 0),
      },
    });
    await this.adjustQuant(db, {
      productId: args.productId,
      lotId: args.lotId,
      locationId: args.srcLocationId,
      dQty: -args.qty,
    });
    await this.adjustQuant(db, {
      productId: args.productId,
      lotId: args.lotId,
      locationId: args.destLocationId,
      dQty: args.qty,
    });
  }

  /** On-hand minus reserved for a product at STOCK, summed across its lots. */
  private async availableAtStock(
    db: Tx | PrismaService,
    productId: string,
    stockLoc: string,
  ): Promise<number> {
    const quants = await db.mfgStockQuant.findMany({
      where: { productId, locationId: stockLoc },
    });
    return round3(quants.reduce((s, q) => s + n(q.quantity) - n(q.reservedQty), 0));
  }

  // ── receipt (P0: nhập kho NVL) ────────────────────────────────────────────

  /**
   * Receive raw material into stock and roll its AVCO forward. Creates a lot
   * when the product is lot-tracked. This is the only inflow that moves a raw
   * product's average cost.
   */
  async receive(dto: {
    productId: string;
    qty: number;
    uomId?: string;
    unitCost: number;
    lotName?: string;
    poLineId?: string;
  }) {
    if (dto.qty <= 0) {
      throw new BadRequestException({ code: 'MFG_QTY_INVALID' });
    }
    const supplier = await this.locationId(this.prisma, 'SUPPLIER');
    const stock = await this.locationId(this.prisma, 'STOCK');

    return this.prisma.$transaction(async (db) => {
      // Lock the product row FIRST, then read it inside the transaction. This
      // serializes the receipt against updateProduct's own FOR UPDATE, so a
      // concurrent base-UoM edit can't land between our read and our write —
      // a stale pre-transaction snapshot here would book stock denominated in
      // the OLD unit right after the edit committed.
      await db.$executeRaw`SELECT 1 FROM "MfgProduct" WHERE "id" = ${dto.productId} FOR UPDATE`;
      const product = await db.mfgProduct.findUnique({
        where: { id: dto.productId },
        include: { uom: true },
      });
      if (!product) throw new NotFoundException({ code: 'MFG_PRODUCT_NOT_FOUND' });
      if (!product.active) {
        throw new BadRequestException({
          code: 'MFG_PRODUCT_ARCHIVED',
          message: 'Sản phẩm đã lưu trữ — bật lại trước khi nhập kho.',
        });
      }
      // Default to the product's own base UoM when the caller omits one.
      const moveUom = await db.mfgUom.findUnique({
        where: { id: dto.uomId ?? product.uomId },
      });
      if (!moveUom) throw new BadRequestException({ code: 'MFG_UOM_NOT_FOUND' });
      const baseQty = toBase(dto.qty, uomLike(moveUom));

      // Optional PO link: the receipt books against a confirmed PO line for the
      // same product, driving qtyReceived and the PO's PARTIAL/RECEIVED state.
      let poLine: { id: string; poId: string } | null = null;
      if (dto.poLineId) {
        const line = await db.mfgPurchaseOrderLine.findUnique({
          where: { id: dto.poLineId },
          include: { po: true },
        });
        if (!line) throw new NotFoundException({ code: 'MFG_PO_LINE_NOT_FOUND' });
        if (line.productId !== dto.productId) {
          throw new BadRequestException({
            code: 'MFG_PO_LINE_PRODUCT_MISMATCH',
            message: 'Dòng đơn mua thuộc sản phẩm khác.',
          });
        }
        if (line.po.state !== 'CONFIRMED' && line.po.state !== 'PARTIAL') {
          throw new BadRequestException({
            code: 'MFG_PO_NOT_OPEN',
            message: 'Đơn mua chưa xác nhận hoặc đã đóng.',
          });
        }
        poLine = { id: line.id, poId: line.poId };
      }

      const onHand = await this.availableAtStock(db, dto.productId, stock);
      const newAvg = avcoAfterReceipt(onHand, n(product.avgCost), baseQty, dto.unitCost);

      let lotId: string | null = null;
      if (product.tracking === 'LOT') {
        const lot = await db.mfgLot.create({
          data: {
            productId: dto.productId,
            name: dto.lotName ?? `RCV-${product.code}-${onHand + baseQty}`,
            mfgDate: new Date(),
            expiryDate: expiryDate(new Date(), product.useExpiration, product.expirationDays),
          },
        });
        lotId = lot.id;
      }

      await this.move(db, {
        productId: dto.productId,
        lotId,
        qty: baseQty,
        uomId: product.uomId,
        srcLocationId: supplier,
        destLocationId: stock,
        refType: 'RECEIPT',
        refId: poLine?.poId,
        unitCost: dto.unitCost,
      });
      await db.mfgProduct.update({
        where: { id: dto.productId },
        data: { avgCost: newAvg },
      });
      if (poLine) {
        await db.mfgPurchaseOrderLine.update({
          where: { id: poLine.id },
          data: { qtyReceived: { increment: round3(baseQty) } },
        });
        const lines = await db.mfgPurchaseOrderLine.findMany({
          where: { poId: poLine.poId },
        });
        const allDone = lines.every((l) => n(l.qtyReceived) >= n(l.qty));
        await db.mfgPurchaseOrder.update({
          where: { id: poLine.poId },
          data: { state: allDone ? 'RECEIVED' : 'PARTIAL' },
        });
      }
      return { productId: dto.productId, avgCost: newAvg, lotId };
    });
  }

  // ── costing (multi-level rollup) ──────────────────────────────────────────

  /**
   * Cost to make one BoM's output, rolled up through nested BoMs. A raw
   * component is valued at its AVCO; a semi-finished one recurses into its
   * active BoM; operations add work-center time. Returns the total plus a
   * breakdown, and the per-unit cost used when a semi is a component elsewhere.
   *
   * [seen] guards against a recipe that (mis)references itself, so a cyclic BoM
   * fails loudly instead of recursing forever.
   */
  async bomCost(
    bomId: string,
    seen: Set<string> = new Set(),
  ): Promise<{
    materialCost: number;
    operationCost: number;
    total: number;
    perUnit: number;
    outputQtyBase: number;
  }> {
    if (seen.has(bomId)) {
      throw new BadRequestException({
        code: 'MFG_BOM_CYCLE',
        message: 'Công thức tham chiếu vòng — không tính được giá thành.',
      });
    }
    seen.add(bomId);

    const bom = await this.prisma.mfgBom.findUnique({
      where: { id: bomId },
      include: {
        uom: true,
        lines: { include: { component: { include: { boms: true } }, uom: true } },
        operations: { include: { workCenter: true } },
      },
    });
    if (!bom) throw new NotFoundException({ code: 'MFG_BOM_NOT_FOUND' });

    let materialCost = 0;
    for (const line of bom.lines) {
      const lineBase = toBase(n(line.qty), uomLike(line.uom));
      if (line.component.type === 'SEMI') {
        const childBom = line.component.boms.find((b) => b.active);
        if (childBom) {
          const child = await this.bomCost(childBom.id, seen);
          materialCost += child.perUnit * lineBase;
          continue;
        }
        // No BoM for the semi yet — fall back to its stored cost.
      }
      const unit = n(line.component.avgCost) || n(line.component.standardCost);
      materialCost += unit * lineBase;
    }

    let operationCost = 0;
    for (const op of bom.operations) {
      operationCost += (op.durationMinutes / 60) * n(op.workCenter.costPerHour);
    }

    const outputQtyBase = toBase(n(bom.outputQty), uomLike(bom.uom));
    const total = roundMoney(materialCost + operationCost);
    const perUnit = outputQtyBase > 0 ? total / outputQtyBase : 0;
    seen.delete(bomId);
    return {
      materialCost: roundMoney(materialCost),
      operationCost: roundMoney(operationCost),
      total,
      perUnit,
      outputQtyBase,
    };
  }

  // ── manufacturing orders ──────────────────────────────────────────────────

  private async nextMoCode(db: Tx | PrismaService): Promise<string> {
    const count = await db.mfgOrder.count();
    return `MO-${String(count + 1).padStart(5, '0')}`;
  }

  /**
   * Create a draft MO from a BoM. Explodes the BoM's lines into components,
   * scaled by how many batches the requested quantity is.
   */
  async createMO(dto: {
    bomId: string;
    qtyToProduce: number;
    scheduledDate?: string;
    responsibleId?: string;
  }) {
    const bom = await this.prisma.mfgBom.findUnique({
      where: { id: dto.bomId },
      include: { lines: { include: { component: true } }, product: true },
    });
    if (!bom) throw new NotFoundException({ code: 'MFG_BOM_NOT_FOUND' });
    // A retired version (createBom retires the old one when saving a new one):
    // hidden from the picker, but a stale client can still post its id — an MO
    // from it would consume the OLD recipe's quantities.
    if (!bom.active) {
      throw new BadRequestException({
        code: 'MFG_BOM_INACTIVE',
        message: 'Công thức đã có phiên bản mới hơn — tải lại danh sách.',
      });
    }
    // Archived output product: its BoM is hidden from the picker, but a stale
    // client (or raw API call) could still post the id — refuse, don't book
    // stock into a product no default list shows.
    if (!bom.product.active) {
      throw new BadRequestException({
        code: 'MFG_PRODUCT_ARCHIVED',
        message: 'Sản phẩm đã lưu trữ — bật lại trước khi tạo lệnh.',
      });
    }
    // Same for an archived INGREDIENT: the recipe still references it, but an
    // MO would go on consuming a product every picker hides.
    const deadLine = bom.lines.find((l) => !l.component.active);
    if (deadLine) {
      throw new BadRequestException({
        code: 'MFG_COMPONENT_ARCHIVED',
        message: `Nguyên liệu "${deadLine.component.nameVi}" đã lưu trữ — sửa công thức trước.`,
      });
    }
    // Type rules re-checked here too: a legacy BoM (authored before the rules)
    // can carry a RAW output or FINISHED input — listBoms hides it, but a
    // stale/raw client can still post its id.
    if (bom.product.type !== 'SEMI' && bom.product.type !== 'FINISHED') {
      throw new BadRequestException({
        code: 'MFG_BOM_OUTPUT_TYPE',
        message: 'Công thức chỉ dành cho bán thành phẩm hoặc thành phẩm.',
      });
    }
    const finishedLine = bom.lines.find((l) => l.component.type === 'FINISHED');
    if (finishedLine) {
      throw new BadRequestException({
        code: 'MFG_BOM_COMPONENT_TYPE',
        message: `"${finishedLine.component.nameVi}" là thành phẩm — không dùng làm nguyên liệu.`,
      });
    }
    if (dto.qtyToProduce <= 0) {
      throw new BadRequestException({ code: 'MFG_QTY_INVALID' });
    }

    const factor = dto.qtyToProduce / n(bom.outputQty);
    const componentCreate = bom.lines.map((l) => ({
      productId: l.componentId,
      qtyToConsume: round3(n(l.qty) * factor),
      uomId: l.uomId,
    }));

    // nextMoCode is count()+1, which two concurrent creates can land on the same
    // value — retry on the unique-violation rather than 500 the request.
    // ponytail: fine at bakery volume; swap to a DB sequence if MO creation
    // ever gets hot.
    for (let attempt = 0; ; attempt++) {
      const code = await this.nextMoCode(this.prisma);
      try {
        return await this.prisma.mfgOrder.create({
          data: {
            code,
            productId: bom.productId,
            bomId: bom.id,
            qtyToProduce: round3(dto.qtyToProduce),
            uomId: bom.uomId,
            scheduledDate: dto.scheduledDate ? new Date(dto.scheduledDate) : null,
            responsibleId: dto.responsibleId,
            components: { create: componentCreate },
          },
          include: { components: true },
        });
      } catch (e) {
        if (
          e instanceof Prisma.PrismaClientKnownRequestError &&
          e.code === 'P2002' &&
          attempt < 5
        ) {
          continue;
        }
        throw e;
      }
    }
  }

  /**
   * Confirm a draft MO: validate the BoM is buildable, generate the work
   * orders from its operations, then compute availability so the badges are
   * ready. An empty BoM (no components) can't be confirmed — Odoo lets you, but
   * a cake with no ingredients is a data error, not a plan.
   */
  async confirmMO(id: string) {
    const mo = await this.prisma.mfgOrder.findUnique({
      where: { id },
      include: { bom: { include: { operations: true, lines: true } } },
    });
    if (!mo) throw new NotFoundException({ code: 'MFG_MO_NOT_FOUND' });
    if (mo.state !== 'DRAFT') {
      throw new ConflictException({
        code: 'MFG_MO_STATE',
        message: `Chỉ xác nhận được MO ở trạng thái Nháp (đang: ${mo.state}).`,
      });
    }
    if (mo.bom.lines.length === 0) {
      throw new BadRequestException({
        code: 'MFG_BOM_INVALID',
        message: 'Công thức không có thành phần — không thể sản xuất.',
      });
    }

    await this.prisma.$transaction(async (db) => {
      for (const op of mo.bom.operations) {
        await db.mfgWorkOrder.create({
          data: {
            moId: mo.id,
            bomOperationId: op.id,
            workCenterId: op.workCenterId,
            sequence: op.sequence,
            durationExpected: op.durationMinutes,
            state: 'READY',
          },
        });
      }
      await db.mfgOrder.update({
        where: { id: mo.id },
        data: { state: 'CONFIRMED' },
      });
    });

    return this.checkAvailability(id);
  }

  /**
   * Recompute each component's Available / Not-available badge from live stock.
   * Non-destructive: it never blocks — the badge is advisory, matching the
   * observed "warn but let production continue" behaviour.
   */
  async checkAvailability(id: string) {
    const mo = await this.prisma.mfgOrder.findUnique({
      where: { id },
      include: { components: true },
    });
    if (!mo) throw new NotFoundException({ code: 'MFG_MO_NOT_FOUND' });
    const stock = await this.locationId(this.prisma, 'STOCK');

    const rows = [];
    for (const c of mo.components) {
      // Free stock PLUS what this MO already holds — otherwise an order that just
      // reserved would flip itself to Not-available (its own hold lowered free).
      const free = await this.availableAtStock(this.prisma, c.productId, stock);
      const avail = round3(free + n(c.reservedQty));
      const ok = avail >= n(c.qtyToConsume);
      await this.prisma.mfgOrderComponent.update({
        where: { id: c.id },
        data: { availability: ok ? 'AVAILABLE' : 'NOT_AVAILABLE' },
      });
      rows.push({
        componentId: c.id,
        productId: c.productId,
        need: n(c.qtyToConsume),
        available: avail,
        status: ok ? 'AVAILABLE' : 'NOT_AVAILABLE',
      });
    }
    return { moId: id, components: rows };
  }

  /**
   * Release an MO's hard reservations: give back exactly what it held on each
   * quant (clamped at 0 so drift can never drive a quant negative) and drop the
   * ledger rows. Filtering by `moId` means it only ever frees this order's own
   * hold — never another order's.
   */
  private async releaseReservations(db: Tx, moId: string): Promise<void> {
    const rows = await db.mfgReservation.findMany({ where: { moId } });
    for (const r of rows) {
      await db.$executeRaw`
        UPDATE "MfgStockQuant"
        SET "reservedQty" = GREATEST(0, "reservedQty" - ${round3(n(r.qty))}::numeric)
        WHERE "id" = ${r.quantId}`;
    }
    await db.mfgReservation.deleteMany({ where: { moId } });
  }

  /**
   * Reserve available stock against the MO's components (FIFO across lots by
   * expiry). Reserves whatever is on hand up to what's needed — a short
   * component reserves what it can and stays Not-available. Each successful
   * allocation writes a `MfgReservation` ledger row so the hold is owned per-MO.
   */
  async reserve(id: string) {
    const mo = await this.prisma.mfgOrder.findUnique({ where: { id } });
    if (!mo) throw new NotFoundException({ code: 'MFG_MO_NOT_FOUND' });
    // Only a confirmed / in-progress MO can hold stock. Reserving a DRAFT (no
    // plan yet) or a terminal DONE/CANCEL order would create a hold with no
    // natural release path. Fast fail; the claim below is the race-safe guard.
    if (mo.state !== 'CONFIRMED' && mo.state !== 'PROGRESS') {
      throw new ConflictException({
        code: 'MFG_MO_STATE',
        message:
          mo.state === 'DRAFT'
            ? 'MO chưa xác nhận — không thể giữ hàng.'
            : `MO đã ${mo.state === 'DONE' ? 'hoàn tất' : 'huỷ'} — không thể giữ hàng.`,
      });
    }
    const stock = await this.locationId(this.prisma, 'STOCK');

    await this.prisma.$transaction(async (db) => {
      // Claim + lock the MO row so two concurrent reserves of the SAME order
      // serialise, and enforce the state race-safely (CONFIRMED → PROGRESS). The
      // components are then re-read INSIDE the lock, so the second reserve sees
      // the first's holds and computes need = 0 instead of double-reserving.
      const claim = await db.mfgOrder.updateMany({
        where: { id, state: { in: ['CONFIRMED', 'PROGRESS'] } },
        data: { state: 'PROGRESS' },
      });
      if (claim.count === 0) {
        throw new ConflictException({
          code: 'MFG_MO_STATE',
          message: 'MO không ở trạng thái giữ hàng được.',
        });
      }

      const components = await db.mfgOrderComponent.findMany({ where: { moId: id } });
      for (const c of components) {
        const need = n(c.qtyToConsume) - n(c.reservedQty);
        if (need <= 0) continue;
        let remaining = need;
        const quants = await db.mfgStockQuant.findMany({
          where: { productId: c.productId, locationId: stock },
          include: { lot: true },
          orderBy: [{ lot: { expiryDate: 'asc' } }, { updatedAt: 'asc' }],
        });
        for (const q of quants) {
          if (remaining <= 0) break;
          const free = n(q.quantity) - n(q.reservedQty);
          if (free <= 0) continue;
          const take = round3(Math.min(free, remaining));
          if (take <= 0) continue;
          // Guarded update: only reserve if the quant STILL has `take` free at
          // write time (re-checked in SQL, not against the stale read), so two
          // concurrent reserves can't both grab the same stock and push
          // reservedQty past quantity. Prisma's where can't express the
          // cross-column `quantity - reservedQty >= take`, hence raw SQL.
          // On contention the row count is 0 — leave it: a best-effort reserve
          // that never oversells is the correct advisory behaviour.
          const reserved = await db.$executeRaw`
            UPDATE "MfgStockQuant"
            SET "reservedQty" = "reservedQty" + ${take}::numeric
            WHERE "id" = ${q.id} AND "quantity" - "reservedQty" >= ${take}::numeric
          `;
          if (reserved === 1) {
            remaining -= take;
            // Record the hard allocation so produce/cancel release only this share.
            await db.mfgReservation.create({
              data: { moId: id, quantId: q.id, productId: c.productId, qty: take },
            });
          }
        }
        await db.mfgOrderComponent.update({
          where: { id: c.id },
          data: { reservedQty: round3(n(c.qtyToConsume) - remaining) },
        });
      }
      // State already claimed to PROGRESS above — nothing more to set here.
    });
    return this.checkAvailability(id);
  }

  /**
   * Complete production. In one transaction: consume every component from stock
   * (recording the moves that make the finished lot traceable), create the
   * finished lot with its mfg/expiry dates, book it into stock, roll the
   * finished product's AVCO forward, and snapshot the cost. The MO lands DONE.
   *
   * Short stock does not stop it — consumption is booked at the planned
   * quantity (backflush), letting the quant go negative rather than silently
   * under-costing the order, which matches "warn but continue".
   */
  async produce(id: string) {
    const stock = await this.locationId(this.prisma, 'STOCK');
    const production = await this.locationId(this.prisma, 'PRODUCTION');

    const mo = await this.prisma.mfgOrder.findUnique({
      where: { id },
      include: {
        product: { include: { uom: true } },
        components: { include: { product: true, uom: true } },
        workOrders: {
          include: {
            workCenter: true,
            bomOperation: { include: { qualityPoints: { where: { active: true } } } },
            qualityChecks: { orderBy: { date: 'desc' } },
          },
        },
      },
    });
    if (!mo) throw new NotFoundException({ code: 'MFG_MO_NOT_FOUND' });
    // Only a confirmed (or in-progress) MO can be produced. A DRAFT has no work
    // orders yet — producing it would skip confirmation (WO generation,
    // availability), leave the QC gate vacuous, and book stock at operationCost
    // = 0. The claim below enforces the same, race-safely.
    if (mo.state !== 'CONFIRMED' && mo.state !== 'PROGRESS') {
      throw new ConflictException({
        code: 'MFG_MO_STATE',
        message:
          mo.state === 'DRAFT'
            ? 'MO chưa xác nhận — không thể sản xuất.'
            : `MO đã ${mo.state === 'DONE' ? 'hoàn tất' : 'huỷ'}.`,
      });
    }
    // The direct "Sản xuất" path enforces the same QC gate as shop-floor doneWO,
    // so a batch can't reach finished stock with a quality point unchecked or
    // failed. An MO with no QC points passes vacuously.
    for (const wo of mo.workOrders) this.assertQcPassed(wo);

    const outQty = n(mo.qtyToProduce);
    if (outQty <= 0) throw new BadRequestException({ code: 'MFG_QTY_INVALID' });

    return this.prisma.$transaction(async (db) => {
      // Claim the MO atomically before any side effect. The pre-transaction
      // state check above is a fast fail, not a guard — two concurrent produce
      // calls can both pass it. This guarded UPDATE row-locks the order; the
      // loser blocks, then re-evaluates its WHERE against the committed DONE
      // state, claims 0 rows, and aborts — so a batch is consumed/booked once.
      const claim = await db.mfgOrder.updateMany({
        where: { id, state: { in: ['CONFIRMED', 'PROGRESS'] } },
        data: { state: 'PROGRESS' },
      });
      if (claim.count === 0) {
        throw new ConflictException({
          code: 'MFG_MO_STATE',
          message: 'MO không ở trạng thái sản xuất được (đã hoàn tất, huỷ, hoặc chưa xác nhận).',
        });
      }

      // Release this MO's own hard reservations first (frees exactly its held
      // share on each quant), so the FIFO consume below works against real
      // on-hand without touching any other order's hold.
      await this.releaseReservations(db, mo.id);

      // ── consume components, FIFO by lot, at their current AVCO ──
      let materialCost = 0;
      for (const c of mo.components) {
        const baseNeed = toBase(n(c.qtyToConsume), uomLike(c.uom));
        materialCost += baseNeed * n(c.product.avgCost);

        let remaining = baseNeed;
        const quants = await db.mfgStockQuant.findMany({
          where: { productId: c.productId, locationId: stock },
          include: { lot: true },
          orderBy: [{ lot: { expiryDate: 'asc' } }, { updatedAt: 'asc' }],
        });
        for (const q of quants) {
          if (remaining <= 0) break;
          // Consume only FREE stock (quantity − reservedQty). This MO's own hold
          // was released above, so any reservedQty left belongs to OTHER orders —
          // taking it would eat a reservation this batch doesn't own. The take is
          // re-checked in SQL at write time (EvalPlanQual re-reads a concurrent
          // consume/reserve's committed value), so two MOs producing the same raw
          // can't both drain the same free stock and drive the quant negative —
          // the loser claims 0 rows and re-reads. Bounded retries drain this quant
          // to its committed free; any true shortfall backflushes below.
          let free = n(q.quantity) - n(q.reservedQty);
          for (let attempt = 0; attempt < 5 && remaining > 0 && free > 0; attempt++) {
            const take = round3(Math.min(free, remaining));
            if (take <= 0) break;
            const took = await db.$executeRaw`
              UPDATE "MfgStockQuant"
              SET "quantity" = "quantity" - ${take}::numeric
              WHERE "id" = ${q.id} AND "quantity" - "reservedQty" >= ${take}::numeric
            `;
            if (took === 1) {
              // Source on-hand already decremented atomically by the guarded UPDATE;
              // record the traceable move + book into production directly (move()
              // would decrement the source a second time).
              await db.mfgStockMove.create({
                data: {
                  productId: c.productId,
                  lotId: q.lotId,
                  qty: take,
                  uomId: c.product.uomId,
                  srcLocationId: stock,
                  destLocationId: production,
                  refType: 'MO',
                  refId: mo.id,
                  unitCost: roundCost(n(c.product.avgCost)),
                },
              });
              await this.adjustQuant(db, {
                productId: c.productId,
                lotId: q.lotId,
                locationId: production,
                dQty: take,
              });
              remaining = round3(remaining - take);
              break;
            }
            // Contention: another tx committed a decrement first. Re-read the
            // committed free and retry with the smaller amount.
            const fresh = await db.mfgStockQuant.findUnique({ where: { id: q.id } });
            free = fresh ? n(fresh.quantity) - n(fresh.reservedQty) : 0;
          }
        }
        // Backflush the shortfall so cost/qty stay whole (quant goes negative).
        // ponytail: the backflush hits the null-lot quant. If a component is NOT
        // lot-tracked, another MO's reservation could sit on that same null-lot
        // quant and this negative would draw it below its reservedQty. Lot-tracked
        // stock (every expiry-tracked ingredient — the norm here) is unaffected:
        // its reservation sits on a lot-quant while the shortfall lands on the
        // separate null-lot quant. Per-quant backflush routing if this ever bites.
        if (remaining > 0) {
          await this.move(db, {
            productId: c.productId,
            lotId: null,
            qty: remaining,
            uomId: c.product.uomId,
            srcLocationId: stock,
            destLocationId: production,
            refType: 'MO',
            refId: mo.id,
            unitCost: n(c.product.avgCost),
          });
        }
        await db.mfgOrderComponent.update({
          where: { id: c.id },
          data: { qtyConsumed: round3(n(c.qtyToConsume)), reservedQty: 0 },
        });
      }

      // ── operations cost (expected time in increment 1) ──
      let operationCost = 0;
      for (const wo of mo.workOrders) {
        const mins = wo.durationReal || wo.durationExpected;
        operationCost += (mins / 60) * n(wo.workCenter.costPerHour);
        await db.mfgWorkOrder.update({
          where: { id: wo.id },
          data: {
            state: 'DONE',
            // Closing straight from produce (never run on the shop floor) banks the
            // standard time, so OEE runtime reflects it instead of reading 0.
            durationReal: wo.durationReal || wo.durationExpected,
            dateFinished: wo.dateFinished ?? new Date(),
          },
        });
      }

      const totalCost = roundMoney(materialCost + operationCost);

      // ── finished lot + book into stock ──
      const outBase = toBase(outQty, uomLike(mo.product.uom));
      const unitCost = outBase > 0 ? totalCost / outBase : 0;
      let lotId: string | null = null;
      if (mo.product.tracking === 'LOT') {
        const lot = await db.mfgLot.create({
          data: {
            productId: mo.productId,
            name: mo.code,
            mfgDate: new Date(),
            expiryDate: expiryDate(new Date(), mo.product.useExpiration, mo.product.expirationDays),
          },
        });
        lotId = lot.id;
      }
      await this.move(db, {
        productId: mo.productId,
        lotId,
        qty: outBase,
        uomId: mo.product.uomId,
        srcLocationId: production,
        destLocationId: stock,
        refType: 'MO',
        refId: mo.id,
        unitCost,
      });

      // ── roll finished AVCO forward ──
      const onHand = await this.availableAtStock(db, mo.productId, stock);
      const newAvg = avcoAfterReceipt(
        onHand - outBase, // on-hand already includes what we just booked
        n(mo.product.avgCost),
        outBase,
        unitCost,
      );
      await db.mfgProduct.update({
        where: { id: mo.productId },
        data: { avgCost: newAvg },
      });

      const updated = await db.mfgOrder.update({
        where: { id: mo.id },
        data: {
          state: 'DONE',
          qtyProduced: round3(outQty),
          totalCost,
          lotId,
        },
      });
      return {
        ...updated,
        cost: {
          materialCost: roundMoney(materialCost),
          operationCost: roundMoney(operationCost),
          total: totalCost,
        },
      };
    });
  }

  async cancelMO(id: string) {
    const mo = await this.prisma.mfgOrder.findUnique({ where: { id } });
    if (!mo) throw new NotFoundException({ code: 'MFG_MO_NOT_FOUND' });
    // Fast fails (informative); the guarded claim inside the transaction is the
    // real, race-safe gate.
    if (mo.state === 'DONE') {
      throw new ConflictException({
        code: 'MFG_MO_STATE',
        message: 'Không thể huỷ MO đã hoàn tất.',
      });
    }
    if (mo.state === 'CANCEL') return { id, state: 'CANCEL' as const };

    return this.prisma.$transaction(async (db) => {
      // Claim the cancel atomically. The row lock serialises against a
      // concurrent produce (which claims the same row): if produce won and set
      // DONE, this claims 0 rows and rejects; and a second concurrent cancel
      // also claims 0 rows, so the reservation release below runs exactly once
      // (no double decrement → reservedQty can't go negative).
      const claim = await db.mfgOrder.updateMany({
        where: { id, state: { notIn: ['DONE', 'CANCEL'] } },
        data: { state: 'CANCEL' },
      });
      if (claim.count === 0) {
        const now = await db.mfgOrder.findUniqueOrThrow({ where: { id } });
        if (now.state === 'DONE') {
          throw new ConflictException({
            code: 'MFG_MO_STATE',
            message: 'Không thể huỷ MO đã hoàn tất.',
          });
        }
        return { id, state: 'CANCEL' as const }; // already cancelled — idempotent
      }

      // Release only THIS MO's hard reservations (ledger rows filtered by moId),
      // so a concurrent order's holds are never freed. The claim above ran once,
      // so this release runs once — reservedQty can't be double-decremented.
      await this.releaseReservations(db, id);
      await db.mfgOrderComponent.updateMany({
        where: { moId: id },
        data: { reservedQty: 0 },
      });
      await db.mfgWorkOrder.updateMany({
        where: { moId: id, state: { notIn: ['DONE', 'CANCEL'] } },
        data: { state: 'CANCEL' },
      });
      return { id, state: 'CANCEL' as const };
    });
  }

  // ── scrap ─────────────────────────────────────────────────────────────────

  /** Move product from stock to the scrap location and log the loss. */
  async scrap(dto: {
    productId: string;
    qty: number;
    uomId?: string;
    reason: string;
    lotId?: string;
    moId?: string;
  }) {
    if (dto.qty <= 0) throw new BadRequestException({ code: 'MFG_QTY_INVALID' });
    const product = await this.prisma.mfgProduct.findUnique({
      where: { id: dto.productId },
    });
    if (!product) throw new NotFoundException({ code: 'MFG_PRODUCT_NOT_FOUND' });
    // Default to the product's own base UoM when the caller omits one.
    const uomId = dto.uomId ?? product.uomId;
    const uom = await this.prisma.mfgUom.findUnique({ where: { id: uomId } });
    if (!uom) throw new BadRequestException({ code: 'MFG_UOM_NOT_FOUND' });

    const stock = await this.locationId(this.prisma, 'STOCK');
    const scrapLoc = await this.locationId(this.prisma, 'SCRAP');
    const baseQty = toBase(dto.qty, uomLike(uom));

    return this.prisma.$transaction(async (db) => {
      const scrap = await db.mfgScrap.create({
        data: {
          productId: dto.productId,
          lotId: dto.lotId ?? null,
          qty: round3(dto.qty),
          uomId,
          locationId: scrapLoc,
          reason: dto.reason,
          moId: dto.moId ?? null,
        },
      });
      await this.move(db, {
        productId: dto.productId,
        lotId: dto.lotId ?? null,
        qty: baseQty,
        uomId: product.uomId,
        srcLocationId: stock,
        destLocationId: scrapLoc,
        refType: 'SCRAP',
        refId: scrap.id,
        unitCost: n(product.avgCost),
      });
      return scrap;
    });
  }

  // ── traceability (backward: finished lot → the raw lots it consumed) ──────

  async traceLot(
    lotId: string,
    depth = 0,
  ): Promise<{
    lotId: string;
    lotName: string;
    product: string;
    producedByMo: string | null;
    consumed: unknown[];
  }> {
    const lot = await this.prisma.mfgLot.findUnique({
      where: { id: lotId },
      include: { product: true },
    });
    if (!lot) throw new NotFoundException({ code: 'MFG_LOT_NOT_FOUND' });

    // The move that booked this lot INTO stock (src=PRODUCTION) names the MO.
    const producingMove = await this.prisma.mfgStockMove.findFirst({
      where: { lotId, refType: 'MO' },
      include: { srcLocation: true, destLocation: true },
      orderBy: { date: 'asc' },
    });
    const producedByMo =
      producingMove && producingMove.srcLocation.type === 'PRODUCTION' ? producingMove.refId : null;

    const consumed: unknown[] = [];
    if (producedByMo && depth < 10) {
      // Component moves for that MO leave stock (src=STOCK) toward PRODUCTION.
      const outMoves = await this.prisma.mfgStockMove.findMany({
        where: { refType: 'MO', refId: producedByMo },
        include: { srcLocation: true, product: true, lot: true },
      });
      for (const m of outMoves) {
        if (m.srcLocation.type !== 'INTERNAL') continue; // skip the finished-in move
        const entry: Record<string, unknown> = {
          product: m.product.code,
          lot: m.lot?.name ?? '(no lot)',
          qty: n(m.qty),
        };
        // A consumed semi-finished lot recurses into its own origin.
        if (m.lotId && m.product.type === 'SEMI') {
          entry.trace = await this.traceLot(m.lotId, depth + 1);
        }
        consumed.push(entry);
      }
    }

    return {
      lotId: lot.id,
      lotName: lot.name,
      product: lot.product.code,
      producedByMo,
      consumed,
    };
  }

  // ── reads ─────────────────────────────────────────────────────────────────

  onHand(productId?: string) {
    return this.prisma.mfgStockQuant.findMany({
      where: productId ? { productId } : undefined,
      include: { product: { include: { uom: true } }, lot: true, location: true },
    });
  }

  expiringLots(beforeIso: string) {
    return this.prisma.mfgLot.findMany({
      // Only lots with stock still on hand: a fully consumed/scrapped lot is
      // history, not a warning — without this filter every expired lot ever
      // made stays on the dashboard forever and the count never returns to 0.
      where: {
        expiryDate: { not: null, lte: new Date(beforeIso) },
        quants: { some: { quantity: { gt: 0 } } },
      },
      include: { product: true },
      orderBy: { expiryDate: 'asc' },
    });
  }

  listMOs(state?: string) {
    return this.prisma.mfgOrder.findMany({
      where: state ? { state: state as never } : undefined,
      include: { product: true, components: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  getMO(id: string) {
    return this.prisma.mfgOrder.findUnique({
      where: { id },
      include: {
        product: { include: { uom: true } },
        bom: true,
        lot: true,
        components: { include: { product: true } },
        workOrders: { include: { workCenter: true, bomOperation: true } },
      },
    });
  }

  // ── master-data reads (for the Sản xuất UI: pick a BoM to build, etc.) ─────

  /** [all] includes archived products — the management screen needs them back. */
  listProducts(type?: string, all = false) {
    return this.prisma.mfgProduct.findMany({
      where: { ...(all ? {} : { active: true }), ...(type ? { type: type as never } : {}) },
      include: { category: true, uom: true },
      orderBy: { code: 'asc' },
    });
  }

  listCategories() {
    return this.prisma.mfgCategory.findMany({ orderBy: { nameVi: 'asc' } });
  }

  listUoms() {
    return this.prisma.mfgUom.findMany({ orderBy: [{ category: 'asc' }, { factor: 'asc' }] });
  }

  // ── product authoring (create/edit/archive master data) ───────────────────

  private async assertProductRefs(db: Tx | PrismaService, categoryId?: string, uomId?: string) {
    if (categoryId) {
      const cat = await db.mfgCategory.findUnique({ where: { id: categoryId } });
      if (!cat) throw new BadRequestException({ code: 'MFG_CATEGORY_NOT_FOUND' });
    }
    if (uomId) {
      const uom = await db.mfgUom.findUnique({ where: { id: uomId } });
      if (!uom) throw new BadRequestException({ code: 'MFG_UOM_NOT_FOUND' });
    }
  }

  /**
   * tracking/useExpiration/expirationDays must be coherent as a WHOLE (post-merge
   * values): expiry only makes sense on lot-tracked products, and useExpiration
   * with 0 days would silently create every lot with a null expiry — the report
   * never warns and FEFO consumes those lots LAST, the opposite of the intent.
   */
  private assertExpiryCoherent(p: {
    tracking: string;
    useExpiration: boolean;
    expirationDays: number;
  }) {
    if (p.tracking !== 'LOT' && p.useExpiration) {
      throw new BadRequestException({
        code: 'MFG_EXPIRY_NEEDS_LOT',
        message: 'HSD chỉ dùng được khi sản phẩm theo dõi theo lô.',
      });
    }
    if (p.useExpiration && p.expirationDays < 1) {
      throw new BadRequestException({
        code: 'MFG_EXPIRY_DAYS_INVALID',
        message: 'Bật HSD thì số ngày sử dụng phải ≥ 1.',
      });
    }
  }

  /** Trimmed, non-empty string or a 400 — whitespace SKUs break lot names/search. */
  private cleanRequired(value: string, code: string) {
    const v = value.trim();
    if (!v) throw new BadRequestException({ code });
    return v;
  }

  async createProduct(dto: {
    code: string;
    nameVi: string;
    nameEn?: string;
    categoryId: string;
    uomId: string;
    type: 'RAW' | 'SEMI' | 'FINISHED' | 'PACKAGING';
    tracking?: 'NONE' | 'LOT';
    useExpiration?: boolean;
    expirationDays?: number;
    standardCost?: number;
    reorderPoint?: number;
  }) {
    const code = this.cleanRequired(dto.code, 'MFG_PRODUCT_CODE_EMPTY');
    const nameVi = this.cleanRequired(dto.nameVi, 'MFG_PRODUCT_NAME_EMPTY');
    const tracking = dto.tracking ?? 'NONE';
    const useExpiration = dto.useExpiration ?? false;
    const expirationDays = dto.expirationDays ?? 0;
    this.assertExpiryCoherent({ tracking, useExpiration, expirationDays });
    await this.assertProductRefs(this.prisma, dto.categoryId, dto.uomId);
    const taken = await this.prisma.mfgProduct.findUnique({ where: { code } });
    if (taken) {
      throw new ConflictException({
        code: 'MFG_PRODUCT_CODE_TAKEN',
        message: `Mã "${code}" đã tồn tại.`,
      });
    }
    try {
      return await this.prisma.mfgProduct.create({
        data: {
          code,
          nameVi,
          nameEn: dto.nameEn?.trim() || nameVi,
          categoryId: dto.categoryId,
          uomId: dto.uomId,
          type: dto.type,
          tracking,
          useExpiration,
          expirationDays,
          standardCost: roundCost(dto.standardCost ?? 0),
          reorderPoint: round3(dto.reorderPoint ?? 0),
        },
        include: { category: true, uom: true },
      });
    } catch (e) {
      // Two same-code creates racing past the pre-check: the loser hits the DB
      // unique constraint — map it to the same 409, not a 500.
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException({
          code: 'MFG_PRODUCT_CODE_TAKEN',
          message: `Mã "${code}" đã tồn tại.`,
        });
      }
      throw e;
    }
  }

  async updateProduct(
    id: string,
    dto: {
      code?: string;
      nameVi?: string;
      nameEn?: string;
      categoryId?: string;
      uomId?: string;
      type?: 'RAW' | 'SEMI' | 'FINISHED' | 'PACKAGING';
      tracking?: 'NONE' | 'LOT';
      useExpiration?: boolean;
      expirationDays?: number;
      standardCost?: number;
      reorderPoint?: number;
      active?: boolean;
    },
  ) {
    const code =
      dto.code !== undefined ? this.cleanRequired(dto.code, 'MFG_PRODUCT_CODE_EMPTY') : undefined;
    const nameVi =
      dto.nameVi !== undefined
        ? this.cleanRequired(dto.nameVi, 'MFG_PRODUCT_NAME_EMPTY')
        : undefined;

    // The whole check-then-update runs in one transaction with the product row
    // locked: receive()/produce() update the product row (AVCO) inside their own
    // transactions, so the lock serializes this edit against a concurrent first
    // stock move — the UoM-lock check below can't be raced stale (TOCTOU).
    return this.prisma.$transaction(async (db) => {
      await db.$executeRaw`SELECT 1 FROM "MfgProduct" WHERE "id" = ${id} FOR UPDATE`;
      const product = await db.mfgProduct.findUnique({ where: { id } });
      if (!product) throw new NotFoundException({ code: 'MFG_PRODUCT_NOT_FOUND' });

      // Coherence is judged on the POST-merge values, so a partial update can't
      // sneak an incoherent combination past the create-time rule.
      this.assertExpiryCoherent({
        tracking: dto.tracking ?? product.tracking,
        useExpiration: dto.useExpiration ?? product.useExpiration,
        expirationDays: dto.expirationDays ?? product.expirationDays,
      });
      await this.assertProductRefs(db, dto.categoryId, dto.uomId);
      if (code !== undefined && code !== product.code) {
        const taken = await db.mfgProduct.findUnique({ where: { code } });
        if (taken) {
          throw new ConflictException({
            code: 'MFG_PRODUCT_CODE_TAKEN',
            message: `Mã "${code}" đã tồn tại.`,
          });
        }
      }
      // Changing the base UoM would silently reinterpret every qty already
      // denominated in it. Stock moves are the obvious case, but BoM lines, BoMs
      // and MO components also freeze quantities against this unit (produce()
      // converts the output with the product's CURRENT uom), so any reference
      // locks it. A freshly created, unwired product stays editable.
      if (dto.uomId && dto.uomId !== product.uomId) {
        const [moves, bomLines, boms, moComponents, moOutputs] = await Promise.all([
          db.mfgStockMove.count({ where: { productId: id } }),
          db.mfgBomLine.count({ where: { componentId: id } }),
          db.mfgBom.count({ where: { productId: id } }),
          db.mfgOrderComponent.count({ where: { productId: id } }),
          db.mfgOrder.count({ where: { productId: id } }),
        ]);
        if (moves + bomLines + boms + moComponents + moOutputs > 0) {
          throw new ConflictException({
            code: 'MFG_PRODUCT_UOM_LOCKED',
            message:
              'Sản phẩm đã có giao dịch kho, công thức hoặc lệnh sản xuất — không đổi được đơn vị gốc.',
          });
        }
      }
      try {
        return await db.mfgProduct.update({
          where: { id },
          data: {
            ...(code !== undefined ? { code } : {}),
            ...(nameVi !== undefined ? { nameVi } : {}),
            ...(dto.nameEn !== undefined ? { nameEn: dto.nameEn } : {}),
            ...(dto.categoryId !== undefined ? { categoryId: dto.categoryId } : {}),
            ...(dto.uomId !== undefined ? { uomId: dto.uomId } : {}),
            ...(dto.type !== undefined ? { type: dto.type } : {}),
            ...(dto.tracking !== undefined ? { tracking: dto.tracking } : {}),
            ...(dto.useExpiration !== undefined ? { useExpiration: dto.useExpiration } : {}),
            ...(dto.expirationDays !== undefined ? { expirationDays: dto.expirationDays } : {}),
            ...(dto.standardCost !== undefined
              ? { standardCost: roundCost(dto.standardCost) }
              : {}),
            ...(dto.reorderPoint !== undefined
              ? { reorderPoint: round3(dto.reorderPoint) }
              : {}),
            ...(dto.active !== undefined ? { active: dto.active } : {}),
          },
          include: { category: true, uom: true },
        });
      } catch (e) {
        if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
          throw new ConflictException({
            code: 'MFG_PRODUCT_CODE_TAKEN',
            message: `Mã "${code}" đã tồn tại.`,
          });
        }
        throw e;
      }
    });
  }

  listBoms() {
    return this.prisma.mfgBom.findMany({
      // An archived product's recipe must leave the "make a batch" picker too,
      // or staff can keep producing a product no other list shows — and a
      // recipe whose INGREDIENT was archived would only fail at createMO, so
      // hide it here as well. Type rules are re-applied on READ, not just at
      // createBom: BoMs authored before the rules existed (old UI allowed any
      // product) may sit in the DB with a RAW output or FINISHED input.
      where: {
        active: true,
        product: { active: true, type: { in: ['SEMI', 'FINISHED'] } },
        lines: { every: { component: { active: true, type: { not: 'FINISHED' } } } },
      },
      include: {
        product: { include: { uom: true } },
        uom: true,
        _count: { select: { lines: true, operations: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  getBom(id: string) {
    return this.prisma.mfgBom.findUnique({
      where: { id },
      include: {
        product: { include: { uom: true } },
        uom: true,
        lines: { include: { component: true, uom: true } },
        operations: { include: { workCenter: true }, orderBy: { sequence: 'asc' } },
      },
    });
  }

  listWorkCenters() {
    return this.prisma.mfgWorkCenter.findMany({
      where: { active: true },
      orderBy: { code: 'asc' },
    });
  }

  // ── BoM authoring (create/edit recipes) ───────────────────────────────────

  /**
   * Validate editor input and shape the nested line/operation rows. Ratio % is
   * derived vs the total base weight of weight-tracked lines — display only, cost
   * and production use each line's qty directly. ponytail: no per-line flour-basis
   * flag is persisted, so the basis is the total; fine for the baker's-% hint.
   */
  private async buildBomData(
    db: Tx,
    input: { lines: BomLineInput[]; operations?: BomOperationInput[] },
  ) {
    if (!input.lines || input.lines.length === 0) {
      throw new BadRequestException({
        code: 'MFG_BOM_NO_LINES',
        message: 'Công thức phải có ít nhất một nguyên liệu.',
      });
    }
    const componentIds = [...new Set(input.lines.map((l) => l.componentId))];
    const uomIds = [...new Set(input.lines.map((l) => l.uomId))];
    const wcIds = [...new Set((input.operations ?? []).map((o) => o.workCenterId))];

    const [components, uoms, wcs] = await Promise.all([
      db.mfgProduct.findMany({
        where: { id: { in: componentIds } },
        select: { id: true, active: true, type: true },
      }),
      db.mfgUom.findMany({ where: { id: { in: uomIds } } }),
      db.mfgWorkCenter.findMany({ where: { id: { in: wcIds } }, select: { id: true } }),
    ]);
    const componentMap = new Map(components.map((c) => [c.id, c]));
    const uomMap = new Map(uoms.map((u) => [u.id, u]));
    const wcSet = new Set(wcs.map((w) => w.id));

    const lineBase: number[] = [];
    let totalBase = 0;
    for (const l of input.lines) {
      const component = componentMap.get(l.componentId);
      if (!component) {
        throw new BadRequestException({
          code: 'MFG_COMPONENT_NOT_FOUND',
          message: 'Nguyên liệu trong công thức không tồn tại.',
        });
      }
      if (!component.active) {
        throw new BadRequestException({
          code: 'MFG_COMPONENT_ARCHIVED',
          message: 'Nguyên liệu trong công thức đã lưu trữ.',
        });
      }
      // A FINISHED good is a sellable output, never an input — picking one as a
      // component is a mis-click that would drain sellable stock on produce.
      if (component.type === 'FINISHED') {
        throw new BadRequestException({
          code: 'MFG_BOM_COMPONENT_TYPE',
          message: 'Thành phẩm không dùng làm nguyên liệu — chọn NVL/bao bì/bán thành phẩm.',
        });
      }
      const uom = uomMap.get(l.uomId);
      if (!uom) throw new BadRequestException({ code: 'MFG_UOM_NOT_FOUND' });
      if (!(l.qty > 0)) throw new BadRequestException({ code: 'MFG_QTY_INVALID' });
      const base = toBase(l.qty, uomLike(uom));
      lineBase.push(base);
      if (uom.category === 'weight') totalBase += base; // baker's % is a weight ratio
    }

    const lines = input.lines.map((l, i) => ({
      componentId: l.componentId,
      qty: round3(l.qty),
      uomId: l.uomId,
      ratioPercent: totalBase > 0 ? Math.round((lineBase[i] / totalBase) * 100 * 10000) / 10000 : 0,
    }));

    const operations = (input.operations ?? []).map((o, i) => {
      if (!wcSet.has(o.workCenterId)) {
        throw new BadRequestException({
          code: 'MFG_WORKCENTER_NOT_FOUND',
          message: 'Công đoạn dùng tổ máy không tồn tại.',
        });
      }
      return {
        sequence: i + 1,
        nameVi: o.nameVi,
        nameEn: o.nameEn && o.nameEn.length > 0 ? o.nameEn : o.nameVi,
        workCenterId: o.workCenterId,
        durationMinutes: Math.max(0, Math.round(o.durationMinutes ?? 0)),
      };
    });

    return { lines, operations };
  }

  /**
   * Create a recipe as a NEW active version and retire the product's previous
   * active BoM, so `bomOf` resolves the latest. Editing in the app posts here too
   * (versioning) rather than mutating in place — that keeps historical MOs and
   * their work orders pointing at the operations they were built from.
   */
  async createBom(dto: {
    productId: string;
    outputQty: number;
    uomId: string;
    lines: BomLineInput[];
    operations?: BomOperationInput[];
  }) {
    return this.prisma.$transaction(async (db) => {
      // Lock output + component product rows (sorted — stable lock order, no
      // deadlock with a sibling createBom), THEN validate inside the same
      // transaction. Validating first and inserting later let a concurrent
      // base-UoM edit or archive land in between — the recipe would reference
      // a product whose unit/state the validation never saw.
      const lockIds = [...new Set([dto.productId, ...dto.lines.map((l) => l.componentId)])].sort();
      // ORDER BY makes the DB acquire the row locks in id order — sorting the
      // JS array alone doesn't constrain the scan order of an IN(...) plan.
      await db.$executeRaw`
        SELECT 1 FROM "MfgProduct" WHERE "id" IN (${Prisma.join(lockIds)})
        ORDER BY "id" FOR UPDATE
      `;
      const product = await db.mfgProduct.findUnique({ where: { id: dto.productId } });
      if (!product) throw new NotFoundException({ code: 'MFG_PRODUCT_NOT_FOUND' });
      if (!product.active) {
        throw new BadRequestException({
          code: 'MFG_PRODUCT_ARCHIVED',
          message: 'Sản phẩm đã lưu trữ — bật lại trước khi tạo công thức.',
        });
      }
      // A recipe only makes sense for something the kitchen MAKES.
      if (product.type !== 'SEMI' && product.type !== 'FINISHED') {
        throw new BadRequestException({
          code: 'MFG_BOM_OUTPUT_TYPE',
          message: 'Công thức chỉ dành cho bán thành phẩm hoặc thành phẩm.',
        });
      }
      const uom = await db.mfgUom.findUnique({ where: { id: dto.uomId } });
      if (!uom) throw new BadRequestException({ code: 'MFG_UOM_NOT_FOUND' });

      const { lines, operations } = await this.buildBomData(db, dto);
      const prev = await db.mfgBom.aggregate({
        where: { productId: dto.productId },
        _max: { version: true },
      });
      const version = (prev._max.version ?? 0) + 1;

      await db.mfgBom.updateMany({
        where: { productId: dto.productId, active: true },
        data: { active: false },
      });
      return db.mfgBom.create({
        data: {
          productId: dto.productId,
          outputQty: round3(dto.outputQty),
          uomId: dto.uomId,
          version,
          active: true,
          lines: { create: lines },
          operations: { create: operations },
        },
        include: { lines: true, operations: true },
      });
    });
  }

  /** Dashboard counts — MOs grouped by state. */
  async moStateCounts() {
    const rows = await this.prisma.mfgOrder.groupBy({
      by: ['state'],
      _count: { _all: true },
    });
    return rows.map((r) => ({ state: r.state, count: r._count._all }));
  }

  // ── reports + replenishment (increment 5) ─────────────────────────────────

  // ponytail: single-site VN bakery on fixed ICT (UTC+7, no DST). Make this
  // configurable if the MES ever runs multi-region.
  private static readonly REPORT_TZ = '+07:00';

  /**
   * Optional date-only range → a Prisma filter, anchored to VN **local** calendar
   * days (not UTC) so a batch made at 06:00 local lands in the right day. `from`
   * is inclusive; `to` covers its whole local day (upper bound = next local
   * midnight, exclusive). Throws 400 on an unparseable date rather than handing
   * Prisma an Invalid Date (which would surface as a 500).
   */
  private dateRange(from?: string, to?: string): { gte?: Date; lt?: Date } | undefined {
    const atLocalMidnight = (day: string): Date => {
      const d = new Date(`${day.slice(0, 10)}T00:00:00${ManufacturingService.REPORT_TZ}`);
      if (Number.isNaN(d.getTime())) {
        throw new BadRequestException({
          code: 'MFG_DATE_INVALID',
          message: `Ngày không hợp lệ: "${day}".`,
        });
      }
      return d;
    };
    const range: { gte?: Date; lt?: Date } = {};
    if (from) range.gte = atLocalMidnight(from);
    if (to) {
      const end = atLocalMidnight(to);
      end.setUTCDate(end.getUTCDate() + 1); // next local midnight, exclusive
      range.lt = end;
    }
    return range.gte || range.lt ? range : undefined;
  }

  /**
   * Production report: finished (DONE) MOs in a window, grouped by product.
   * Output qty and cost are the produce-time snapshots on the MO (qtyProduced,
   * totalCost) — DONE is terminal so they never drift. Qty is not totalled
   * across products (mixed UoM); only đồng and MO count are.
   */
  async productionReport(from?: string, to?: string) {
    const when = this.dateRange(from, to);
    const mos = await this.prisma.mfgOrder.findMany({
      where: { state: 'DONE', ...(when ? { updatedAt: when } : {}) },
      include: { product: { include: { uom: true } } },
    });

    const byProduct = new Map<
      string,
      {
        productId: string;
        productCode: string;
        productNameVi: string;
        uomCode: string;
        moCount: number;
        qtyProduced: number;
        totalCost: number;
      }
    >();
    for (const mo of mos) {
      const row = byProduct.get(mo.productId) ?? {
        productId: mo.productId,
        productCode: mo.product.code,
        productNameVi: mo.product.nameVi,
        uomCode: mo.product.uom.code,
        moCount: 0,
        qtyProduced: 0,
        totalCost: 0,
      };
      row.moCount += 1;
      row.qtyProduced += n(mo.qtyProduced);
      row.totalCost += n(mo.totalCost);
      byProduct.set(mo.productId, row);
    }

    const rows = [...byProduct.values()]
      .map((r) => ({
        ...r,
        qtyProduced: round3(r.qtyProduced),
        totalCost: roundMoney(r.totalCost),
        avgUnitCost: r.qtyProduced > 0 ? roundCost(r.totalCost / r.qtyProduced) : 0,
      }))
      .sort((a, b) => b.totalCost - a.totalCost);

    return {
      from: from ?? null,
      to: to ?? null,
      rows,
      totals: {
        moCount: mos.length,
        totalCost: roundMoney(rows.reduce((s, r) => s + r.totalCost, 0)),
      },
    };
  }

  /**
   * Scrap report over a window. MfgScrap carries no cost column — value is read
   * from the paired stock move (refType SCRAP, refId = scrap.id), whose unitCost
   * is the AVCO snapshot frozen at scrap time (live avgCost would drift on later
   * receipts). Grouped by reason (value only — qty across products is mixed-UoM)
   * and by product (qty + value).
   */
  async scrapReport(from?: string, to?: string) {
    const when = this.dateRange(from, to);
    const scraps = await this.prisma.mfgScrap.findMany({
      where: when ? { date: when } : undefined,
      include: { product: { include: { uom: true } } },
    });
    if (scraps.length === 0) {
      return {
        from: from ?? null,
        to: to ?? null,
        byReason: [],
        byProduct: [],
        totals: { value: 0, count: 0 },
      };
    }

    const moves = await this.prisma.mfgStockMove.findMany({
      where: { refType: 'SCRAP', refId: { in: scraps.map((s) => s.id) } },
      select: { refId: true, qty: true, unitCost: true },
    });
    // Value and qty come from the paired move, not from MfgScrap.qty: the move
    // holds the base-UoM quantity and the frozen đồng-per-base unit cost, while
    // MfgScrap.qty is in the caller's input UoM (kg vs g) — multiplying scrap.qty
    // by a per-base cost mis-values any non-base-UoM scrap.
    const moveOf = new Map(moves.map((m) => [m.refId, m]));

    const byReason = new Map<string, { reason: string; value: number; count: number }>();
    const byProduct = new Map<
      string,
      {
        productId: string;
        productCode: string;
        productNameVi: string;
        uomCode: string;
        qty: number;
        value: number;
        count: number;
      }
    >();
    let totalValue = 0;
    for (const s of scraps) {
      const mv = moveOf.get(s.id);
      const baseQty = mv ? n(mv.qty) : 0; // base UoM (matches product.uom.code)
      const value = baseQty * (mv ? n(mv.unitCost) : 0);
      totalValue += value;

      const r = byReason.get(s.reason) ?? { reason: s.reason, value: 0, count: 0 };
      r.value += value;
      r.count += 1;
      byReason.set(s.reason, r);

      const p = byProduct.get(s.productId) ?? {
        productId: s.productId,
        productCode: s.product.code,
        productNameVi: s.product.nameVi,
        uomCode: s.product.uom.code,
        qty: 0,
        value: 0,
        count: 0,
      };
      p.qty += baseQty;
      p.value += value;
      p.count += 1;
      byProduct.set(s.productId, p);
    }

    return {
      from: from ?? null,
      to: to ?? null,
      byReason: [...byReason.values()]
        .map((r) => ({ ...r, value: roundMoney(r.value) }))
        .sort((a, b) => b.value - a.value),
      byProduct: [...byProduct.values()]
        .map((p) => ({ ...p, qty: round3(p.qty), value: roundMoney(p.value) }))
        .sort((a, b) => b.value - a.value),
      totals: { value: roundMoney(totalValue), count: scraps.length },
    };
  }

  /**
   * Cost report: for each DONE MO in a window, the actual material-vs-operation
   * split. Materials are summed from the MO's consume moves (refType MO, booked
   * INTO the PRODUCTION location) at their frozen unit cost; operations are the
   * remainder of the produce-time totalCost snapshot — so material + operation
   * equals totalCost exactly, no rounding drift.
   */
  async costReport(from?: string, to?: string) {
    const when = this.dateRange(from, to);
    const production = await this.locationId(this.prisma, 'PRODUCTION');
    const mos = await this.prisma.mfgOrder.findMany({
      where: { state: 'DONE', ...(when ? { updatedAt: when } : {}) },
      include: { product: true, uom: true },
      orderBy: { updatedAt: 'desc' },
    });
    if (mos.length === 0) {
      return {
        from: from ?? null,
        to: to ?? null,
        rows: [],
        totals: { materialCost: 0, operationCost: 0, totalCost: 0 },
      };
    }

    const consumes = await this.prisma.mfgStockMove.findMany({
      where: { refType: 'MO', destLocationId: production, refId: { in: mos.map((m) => m.id) } },
      select: { refId: true, qty: true, unitCost: true },
    });
    const materialByMo = new Map<string, number>();
    for (const mv of consumes) {
      if (!mv.refId) continue;
      materialByMo.set(mv.refId, (materialByMo.get(mv.refId) ?? 0) + n(mv.qty) * n(mv.unitCost));
    }

    const rows = mos.map((mo) => {
      const total = roundMoney(n(mo.totalCost));
      const material = roundMoney(materialByMo.get(mo.id) ?? 0);
      const operation = total - material; // remainder → split sums to total exactly
      const produced = n(mo.qtyProduced);
      return {
        moId: mo.id,
        code: mo.code,
        productNameVi: mo.product.nameVi,
        qtyProduced: round3(produced),
        uomCode: mo.uom.code,
        materialCost: material,
        operationCost: operation,
        totalCost: total,
        unitCost: produced > 0 ? roundCost(total / produced) : 0,
      };
    });

    return {
      from: from ?? null,
      to: to ?? null,
      rows,
      totals: {
        materialCost: roundMoney(rows.reduce((s, r) => s + r.materialCost, 0)),
        operationCost: roundMoney(rows.reduce((s, r) => s + r.operationCost, 0)),
        totalCost: roundMoney(rows.reduce((s, r) => s + r.totalCost, 0)),
      },
    };
  }

  /**
   * Replenishment suggestion: for every purchased item (RAW / PACKAGING), the
   * shortfall between demand from open MOs and free stock. Advisory only — it
   * recommends what to buy (act on it in Odoo); it creates nothing.
   *   demand    = Σ (qtyToConsume − qtyConsumed) over DRAFT/CONFIRMED/PROGRESS MOs
   *   onHand    = Σ quantity at STOCK (gross — see below)
   *   shortfall = demand − onHand (only positive rows are returned)
   *
   * On-hand is **gross**, not free (quantity, not quantity − reservedQty): a
   * reserved quant is still physically in stock and earmarked for one of the very
   * open MOs whose full remaining need is already in `demand`. Subtracting
   * reservedQty would net that stock out of supply while its demand stays gross —
   * double-counting the reservation and recommending you re-buy stock you hold.
   */
  async replenishment() {
    const stock = await this.locationId(this.prisma, 'STOCK');

    // Purchased products always; produced ones (SEMI/FINISHED) only when a
    // reorder point watches them — their shortfall means "make more", not "buy".
    const products = await this.prisma.mfgProduct.findMany({
      where: {
        active: true,
        OR: [
          { type: { in: ['RAW', 'PACKAGING'] } },
          { reorderPoint: { gt: 0 } },
        ],
      },
      include: { uom: true },
      orderBy: { code: 'asc' },
    });
    const purchasedIds = new Set(
      products.filter((p) => p.type === 'RAW' || p.type === 'PACKAGING').map((p) => p.id),
    );

    // Demand: open-MO component needs, grouped by product.
    const components = await this.prisma.mfgOrderComponent.findMany({
      where: { mo: { state: { in: ['DRAFT', 'CONFIRMED', 'PROGRESS'] } } },
      select: { productId: true, qtyToConsume: true, qtyConsumed: true },
    });
    const demandBy = new Map<string, number>();
    for (const c of components) {
      if (!purchasedIds.has(c.productId)) continue;
      const need = n(c.qtyToConsume) - n(c.qtyConsumed);
      if (need <= 0) continue;
      demandBy.set(c.productId, (demandBy.get(c.productId) ?? 0) + need);
    }

    // Gross on-hand at STOCK, grouped by product (reservedQty is NOT subtracted —
    // see the method docstring for why netting it would double-count).
    const quants = await this.prisma.mfgStockQuant.findMany({
      where: { locationId: stock, productId: { in: products.map((p) => p.id) } },
      select: { productId: true, quantity: true },
    });
    const onHandBy = new Map<string, number>();
    for (const q of quants) {
      onHandBy.set(q.productId, (onHandBy.get(q.productId) ?? 0) + n(q.quantity));
    }

    const rows = products
      .map((p) => {
        // Demand = open-MO needs, floored by the product's reorder point — so a
        // watched item raises a row as soon as free stock dips under its
        // minimum, even with no MO open.
        const demand = Math.max(demandBy.get(p.id) ?? 0, n(p.reorderPoint));
        const available = onHandBy.get(p.id) ?? 0;
        const shortfall = demand - available;
        const avgCost = n(p.avgCost);
        return {
          productId: p.id,
          productCode: p.code,
          productNameVi: p.nameVi,
          uomCode: p.uom.code,
          // BUY = purchased from a supplier; MAKE = produced in the kitchen.
          kind: purchasedIds.has(p.id) ? ('BUY' as const) : ('MAKE' as const),
          demand: round3(demand),
          available: round3(available),
          shortfall: round3(shortfall),
          avgCost: roundCost(avgCost),
          estCost: roundMoney(shortfall * avgCost),
        };
      })
      .filter((r) => r.shortfall > 0)
      .sort((a, b) => b.estCost - a.estCost);

    return {
      rows,
      totals: { estCost: roundMoney(rows.reduce((s, r) => s + r.estCost, 0)) },
    };
  }

  // ── maintenance + OEE (increment 8) ───────────────────────────────────────

  async createMaintenance(dto: {
    workCenterId: string;
    type?: 'PREVENTIVE' | 'CORRECTIVE';
    scheduledDate: string;
    note?: string;
  }) {
    const wc = await this.prisma.mfgWorkCenter.findUnique({ where: { id: dto.workCenterId } });
    if (!wc) throw new NotFoundException({ code: 'MFG_WORKCENTER_NOT_FOUND' });
    return this.prisma.mfgMaintenance.create({
      data: {
        workCenterId: dto.workCenterId,
        type: dto.type ?? 'PREVENTIVE',
        scheduledDate: new Date(dto.scheduledDate),
        note: dto.note ?? null,
      },
      include: { workCenter: true },
    });
  }

  listMaintenance(state?: string) {
    return this.prisma.mfgMaintenance.findMany({
      where: state ? { state: state as never } : undefined,
      include: { workCenter: true },
      orderBy: [{ state: 'asc' }, { scheduledDate: 'asc' }],
    });
  }

  /** Close a planned job: stamp doneDate + record its downtime (feeds OEE). */
  async completeMaintenance(id: string, dto: { downtimeMin?: number }) {
    const claim = await this.prisma.mfgMaintenance.updateMany({
      where: { id, state: 'PLANNED' },
      data: {
        state: 'DONE',
        doneDate: new Date(),
        downtimeMin: Math.max(0, Math.round(dto.downtimeMin ?? 0)),
      },
    });
    if (claim.count === 0) {
      const exists = await this.prisma.mfgMaintenance.findUnique({ where: { id } });
      if (!exists) throw new NotFoundException({ code: 'MFG_MAINT_NOT_FOUND' });
      throw new ConflictException({
        code: 'MFG_MAINT_STATE',
        message: 'Việc bảo trì đã hoàn tất.',
      });
    }
    return this.prisma.mfgMaintenance.findUniqueOrThrow({
      where: { id },
      include: { workCenter: true },
    });
  }

  /**
   * OEE per work centre over a window. **Approximate by design** — a bakery has no
   * shift/planned-time config, so:
   *   - availability = runtime / (runtime + maintenance downtime)
   *   - performance  = Σ standard minutes / Σ real minutes (>1 = faster than std)
   *   - quality      = passed QC checks / total QC checks (1 if none)
   *   - OEE          = availability × min(performance, 1) × quality
   * Directional, not audit-grade; documented in docs/kitchen-mes.md.
   */
  async oeeReport(from?: string, to?: string) {
    const when = this.dateRange(from, to);
    const woWhere = { state: 'DONE' as const, ...(when ? { dateFinished: when } : {}) };
    const [wos, maint, checks, centers] = await Promise.all([
      this.prisma.mfgWorkOrder.findMany({
        where: woWhere,
        select: { workCenterId: true, durationReal: true, durationExpected: true },
      }),
      this.prisma.mfgMaintenance.findMany({
        where: { state: 'DONE', ...(when ? { doneDate: when } : {}) },
        select: { workCenterId: true, downtimeMin: true },
      }),
      this.prisma.mfgQualityCheck.findMany({
        where: { workOrder: woWhere },
        select: { result: true, workOrder: { select: { workCenterId: true } } },
      }),
      this.prisma.mfgWorkCenter.findMany({
        where: { active: true },
        select: { id: true, code: true, nameVi: true },
      }),
    ]);

    type Acc = {
      runtime: number;
      standard: number;
      downtime: number;
      checks: number;
      fails: number;
      woCount: number;
    };
    const agg = new Map<string, Acc>();
    const acc = (id: string): Acc => {
      let a = agg.get(id);
      if (!a) {
        a = { runtime: 0, standard: 0, downtime: 0, checks: 0, fails: 0, woCount: 0 };
        agg.set(id, a);
      }
      return a;
    };
    for (const w of wos) {
      const a = acc(w.workCenterId);
      a.runtime += w.durationReal;
      a.standard += w.durationExpected;
      a.woCount += 1;
    }
    for (const m of maint) acc(m.workCenterId).downtime += m.downtimeMin;
    for (const c of checks) {
      if (!c.workOrder) continue;
      const a = acc(c.workOrder.workCenterId);
      a.checks += 1;
      if (c.result === 'FAIL') a.fails += 1;
    }

    const r2 = (x: number) => Math.round(x * 100) / 100;
    const rows = centers
      .map((wc) => {
        const a = agg.get(wc.id) ?? {
          runtime: 0,
          standard: 0,
          downtime: 0,
          checks: 0,
          fails: 0,
          woCount: 0,
        };
        const availability = a.runtime + a.downtime > 0 ? a.runtime / (a.runtime + a.downtime) : 1;
        const performance = a.runtime > 0 ? a.standard / a.runtime : 0;
        const quality = a.checks > 0 ? (a.checks - a.fails) / a.checks : 1;
        const oee = availability * Math.min(performance, 1) * quality;
        return {
          workCenterId: wc.id,
          code: wc.code,
          nameVi: wc.nameVi,
          woCount: a.woCount,
          runtimeMin: a.runtime,
          downtimeMin: a.downtime,
          availability: r2(availability),
          performance: r2(performance),
          quality: r2(quality),
          oee: r2(oee),
        };
      })
      .filter((r) => r.woCount > 0 || r.downtimeMin > 0)
      .sort((a, b) => b.oee - a.oee);

    return { from: from ?? null, to: to ?? null, rows };
  }

  // ── planning (schedule + employee assignment) ─────────────────────────────

  /** Kitchen users who can be assigned to run an MO. */
  listStaff() {
    return this.prisma.user.findMany({
      where: {
        role: { in: [Role.KITCHEN_MANAGER, Role.KITCHEN_STAFF, Role.ADMIN] },
        isActive: true,
      },
      select: { id: true, fullName: true },
      orderBy: { fullName: 'asc' },
    });
  }

  /**
   * The planning board feed: every MO not yet finished (Draft / Confirmed /
   * In-progress), with its scheduled day and assignee resolved. responsibleId
   * is a soft link (a plain user id, so the manufacturing side stays namespaced
   * off the User model) — names are batch-resolved here, not by a FK join.
   */
  async schedule() {
    const mos = await this.prisma.mfgOrder.findMany({
      where: { state: { in: ['DRAFT', 'CONFIRMED', 'PROGRESS'] } },
      include: { product: { include: { uom: true } } },
      orderBy: [{ scheduledDate: { sort: 'asc', nulls: 'last' } }, { createdAt: 'asc' }],
    });

    const ids = [...new Set(mos.map((m) => m.responsibleId).filter((x): x is string => !!x))];
    const users = ids.length
      ? await this.prisma.user.findMany({
          where: { id: { in: ids } },
          select: { id: true, fullName: true },
        })
      : [];
    const nameOf = new Map(users.map((u) => [u.id, u.fullName]));

    return mos.map((m) => ({
      id: m.id,
      code: m.code,
      productNameVi: m.product.nameVi,
      uomCode: m.product.uom.code,
      qtyToProduce: m.qtyToProduce,
      state: m.state,
      scheduledDate: m.scheduledDate,
      responsibleId: m.responsibleId,
      responsibleName: m.responsibleId ? (nameOf.get(m.responsibleId) ?? null) : null,
    }));
  }

  /**
   * Set (or clear) an MO's scheduled date and/or responsible person. A finished
   * or cancelled MO can't be rescheduled — its plan is history.
   */
  async planMO(id: string, dto: { scheduledDate?: string | null; responsibleId?: string | null }) {
    const mo = await this.prisma.mfgOrder.findUnique({ where: { id } });
    if (!mo) throw new NotFoundException({ code: 'MFG_MO_NOT_FOUND' });
    if (mo.state === 'DONE' || mo.state === 'CANCEL') {
      throw new ConflictException({
        code: 'MFG_MO_STATE',
        message: 'Không thể lên lịch cho MO đã kết thúc.',
      });
    }
    if (dto.responsibleId) {
      // Only an active kitchen user is assignable — the same set listStaff
      // offers. Guards against assigning (and thereby surfacing the name of) an
      // arbitrary or deactivated account.
      const user = await this.prisma.user.findFirst({
        where: {
          id: dto.responsibleId,
          isActive: true,
          role: { in: [Role.KITCHEN_MANAGER, Role.KITCHEN_STAFF, Role.ADMIN] },
        },
      });
      if (!user) {
        throw new BadRequestException({
          code: 'MFG_USER_NOT_ASSIGNABLE',
          message: 'Người phụ trách phải là nhân sự bếp đang hoạt động.',
        });
      }
    }

    const data: Prisma.MfgOrderUpdateInput = {};
    if (dto.scheduledDate !== undefined) {
      data.scheduledDate = dto.scheduledDate ? new Date(dto.scheduledDate) : null;
    }
    if (dto.responsibleId !== undefined) {
      data.responsibleId = dto.responsibleId;
    }
    return this.prisma.mfgOrder.update({ where: { id }, data });
  }

  // ── shop floor: work-order execution ──────────────────────────────────────

  /** Open work orders for the tablet board — grouped-ready by work center. */
  shopFloor(workCenterId?: string) {
    return this.prisma.mfgWorkOrder.findMany({
      where: {
        state: { in: ['READY', 'PROGRESS', 'BLOCKED'] },
        ...(workCenterId ? { workCenterId } : {}),
      },
      include: {
        workCenter: true,
        mo: { include: { product: true } },
        bomOperation: {
          include: { qualityPoints: { where: { active: true } } },
        },
        qualityChecks: { orderBy: { date: 'desc' } },
      },
      orderBy: [{ workCenterId: 'asc' }, { sequence: 'asc' }],
    });
  }

  private async wo(id: string) {
    const wo = await this.prisma.mfgWorkOrder.findUnique({ where: { id } });
    if (!wo) throw new NotFoundException({ code: 'MFG_WO_NOT_FOUND' });
    return wo;
  }

  /**
   * Throw unless every active quality point on a work order's operation has a
   * LATEST PASS check (a re-measure supersedes an earlier fail). Shared by
   * doneWO (shop floor) and produce (the direct "Sản xuất" button) so finished
   * stock can never be booked with a QC point skipped or failed, whichever path
   * closes the order.
   */
  private assertQcPassed(wo: {
    bomOperation: { qualityPoints: { id: string; titleVi: string }[] };
    qualityChecks: { qualityPointId: string; result: string }[];
  }): void {
    for (const qp of wo.bomOperation.qualityPoints) {
      const latest = wo.qualityChecks.find((c) => c.qualityPointId === qp.id);
      if (!latest) {
        throw new BadRequestException({
          code: 'MFG_QC_REQUIRED',
          message: `Cần kiểm tra "${qp.titleVi}" (đạt) trước khi hoàn tất.`,
        });
      }
      if (latest.result === 'FAIL') {
        throw new BadRequestException({
          code: 'MFG_QC_FAILED',
          message: `Kiểm tra "${qp.titleVi}" KHÔNG đạt — không thể hoàn tất.`,
        });
      }
    }
  }

  /** Start (or resume) a work order — marks the current run's start. */
  async startWO(id: string) {
    const wo = await this.wo(id); // existence + moId
    // Guarded claim: row-locks and re-checks state, so a concurrent doneWO/cancel
    // can't be reverted to PROGRESS by a racing start.
    const claim = await this.prisma.mfgWorkOrder.updateMany({
      where: { id, state: { notIn: ['DONE', 'CANCEL'] } },
      data: { state: 'PROGRESS', dateStart: new Date() },
    });
    if (claim.count === 0) {
      throw new ConflictException({ code: 'MFG_WO_STATE', message: 'Công đoạn đã kết thúc.' });
    }
    // Only revive the MO to PROGRESS if it's still open — never resurrect a terminal MO.
    await this.prisma.mfgOrder.updateMany({
      where: { id: wo.moId, state: { in: ['CONFIRMED', 'PROGRESS'] } },
      data: { state: 'PROGRESS' },
    });
    return this.wo(id);
  }

  /**
   * Pause — bank the elapsed run time and go back to Ready. The banking is a
   * single guarded UPDATE: it increments `durationReal` from the row's own
   * `dateStart` and re-checks `state = 'PROGRESS'` under the row lock, so two
   * concurrent pauses (or a pause racing a done) can't lose each other's time or
   * stomp each other's state.
   */
  async pauseWO(id: string) {
    const affected = await this.prisma.$executeRaw`
      UPDATE "MfgWorkOrder"
      SET "state" = 'READY',
          "durationReal" = "durationReal" + GREATEST(0, ROUND((EXTRACT(EPOCH FROM (now() - "dateStart")) / 60)::numeric))::int,
          "dateStart" = NULL
      WHERE "id" = ${id} AND "state" = 'PROGRESS'`;
    if (affected === 0) {
      await this.wo(id); // throws MFG_WO_NOT_FOUND if the row is gone
      throw new ConflictException({ code: 'MFG_WO_STATE', message: 'Công đoạn không đang chạy.' });
    }
    return this.wo(id);
  }

  /**
   * Finish a work order. Blocked until every active quality point on its
   * operation has a PASS check — a FAIL or a missing check stops it, so a batch
   * can't be signed off with an open QC item. The close itself is a guarded
   * UPDATE (banks the final run time and re-checks the row isn't already
   * terminal), so it applies exactly once under concurrent finishes.
   */
  async doneWO(id: string) {
    const wo = await this.prisma.mfgWorkOrder.findUnique({
      where: { id },
      include: {
        bomOperation: { include: { qualityPoints: { where: { active: true } } } },
        qualityChecks: { orderBy: { date: 'desc' } },
      },
    });
    if (!wo) throw new NotFoundException({ code: 'MFG_WO_NOT_FOUND' });
    if (wo.state === 'DONE' || wo.state === 'CANCEL') {
      throw new ConflictException({ code: 'MFG_WO_STATE', message: 'Công đoạn đã kết thúc.' });
    }

    this.assertQcPassed(wo);

    const affected = await this.prisma.$executeRaw`
      UPDATE "MfgWorkOrder"
      SET "state" = 'DONE',
          "durationReal" = "durationReal" + GREATEST(0, ROUND((EXTRACT(EPOCH FROM (now() - "dateStart")) / 60)::numeric))::int,
          "dateFinished" = now()
      WHERE "id" = ${id} AND "state" NOT IN ('DONE', 'CANCEL')`;
    if (affected === 0) {
      throw new ConflictException({ code: 'MFG_WO_STATE', message: 'Công đoạn đã kết thúc.' });
    }
    return this.wo(id);
  }

  // ── quality control ───────────────────────────────────────────────────────

  createQualityPoint(dto: {
    titleVi: string;
    titleEn: string;
    testType: 'MEASURE' | 'PASS_FAIL';
    bomOperationId?: string;
    productId?: string;
    normMin?: number;
    normMax?: number;
    unit?: string;
  }) {
    return this.prisma.mfgQualityPoint.create({ data: dto });
  }

  listQualityPoints(bomOperationId?: string) {
    return this.prisma.mfgQualityPoint.findMany({
      where: { active: true, ...(bomOperationId ? { bomOperationId } : {}) },
      include: { bomOperation: true },
      orderBy: { createdAt: 'asc' },
    });
  }

  /**
   * Record a QC result against a work order. For a MEASURE point the verdict is
   * computed here — PASS only when the value is within [normMin, normMax] — so a
   * tablet just sends the number. A FAIL opens a quality alert automatically.
   */
  async recordCheck(dto: {
    qualityPointId: string;
    workOrderId: string;
    measuredValue?: number;
    passFail?: 'PASS' | 'FAIL';
    note?: string;
    userId?: string;
  }) {
    const qp = await this.prisma.mfgQualityPoint.findUnique({
      where: { id: dto.qualityPointId },
    });
    if (!qp) throw new NotFoundException({ code: 'MFG_QP_NOT_FOUND' });
    const wo = await this.prisma.mfgWorkOrder.findUnique({
      where: { id: dto.workOrderId },
    });
    if (!wo) throw new NotFoundException({ code: 'MFG_WO_NOT_FOUND' });

    let result: 'PASS' | 'FAIL';
    if (qp.testType === 'MEASURE') {
      if (dto.measuredValue == null) {
        throw new BadRequestException({
          code: 'MFG_QC_VALUE_REQUIRED',
          message: 'Cần nhập giá trị đo.',
        });
      }
      const v = dto.measuredValue;
      const okMin = qp.normMin == null || v >= n(qp.normMin);
      const okMax = qp.normMax == null || v <= n(qp.normMax);
      result = okMin && okMax ? 'PASS' : 'FAIL';
    } else {
      if (dto.passFail == null) {
        throw new BadRequestException({
          code: 'MFG_QC_RESULT_REQUIRED',
          message: 'Cần chọn Đạt / Không đạt.',
        });
      }
      result = dto.passFail;
    }

    return this.prisma.$transaction(async (db) => {
      const check = await db.mfgQualityCheck.create({
        data: {
          qualityPointId: dto.qualityPointId,
          workOrderId: dto.workOrderId,
          moId: wo.moId,
          result,
          measuredValue: dto.measuredValue ?? null,
          note: dto.note,
          userId: dto.userId,
        },
      });
      if (result === 'FAIL') {
        await db.mfgQualityAlert.create({
          data: {
            title: `QC không đạt: ${qp.titleVi}`,
            moId: wo.moId,
            description:
              dto.measuredValue != null
                ? `Giá trị đo ${dto.measuredValue}${qp.unit ?? ''} ngoài ngưỡng.`
                : 'Kiểm tra Đạt/Không đạt: KHÔNG đạt.',
          },
        });
      }
      return check;
    });
  }

  listAlerts(stage?: string) {
    return this.prisma.mfgQualityAlert.findMany({
      where: stage ? { stage: stage as never } : undefined,
      include: { mo: true, product: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async setAlertStage(id: string, stage: 'NEW' | 'CONFIRMED' | 'SOLVED') {
    const alert = await this.prisma.mfgQualityAlert.findUnique({ where: { id } });
    if (!alert) throw new NotFoundException({ code: 'MFG_ALERT_NOT_FOUND' });
    return this.prisma.mfgQualityAlert.update({ where: { id }, data: { stage } });
  }

  // ── purchasing (P2: suppliers + purchase orders + history) ────────────────

  private static readonly PO_INCLUDE = {
    supplier: true,
    lines: { include: { product: { include: { uom: true } } } },
  } satisfies Prisma.MfgPurchaseOrderInclude;

  listSuppliers(includeInactive = false) {
    return this.prisma.mfgSupplier.findMany({
      where: includeInactive ? undefined : { active: true },
      orderBy: { name: 'asc' },
    });
  }

  createSupplier(dto: CreateSupplierDto) {
    return this.prisma.mfgSupplier.create({ data: { ...dto } });
  }

  async updateSupplier(id: string, dto: UpdateSupplierDto) {
    const existing = await this.prisma.mfgSupplier.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException({ code: 'MFG_SUPPLIER_NOT_FOUND' });
    return this.prisma.mfgSupplier.update({ where: { id }, data: { ...dto } });
  }

  listPurchaseOrders(state?: string) {
    return this.prisma.mfgPurchaseOrder.findMany({
      where: state ? { state: state as never } : undefined,
      include: ManufacturingService.PO_INCLUDE,
      orderBy: { createdAt: 'desc' },
    });
  }

  async getPurchaseOrder(id: string) {
    const po = await this.prisma.mfgPurchaseOrder.findUnique({
      where: { id },
      include: ManufacturingService.PO_INCLUDE,
    });
    if (!po) throw new NotFoundException({ code: 'MFG_PO_NOT_FOUND' });
    return po;
  }

  /**
   * Line quantities are in the product's own base UoM — the same convention
   * receive() defaults to, so a PO line and its receipts always compare 1:1.
   */
  private async validatePoLines(lines: { productId: string; qty: number; unitPrice: number }[]) {
    if (!Array.isArray(lines) || lines.length === 0) {
      throw new BadRequestException({
        code: 'MFG_PO_LINES_EMPTY',
        message: 'Đơn mua cần ít nhất một dòng hàng.',
      });
    }
    const products = await this.prisma.mfgProduct.findMany({
      where: { id: { in: lines.map((l) => l.productId) } },
      select: { id: true, uomId: true, active: true },
    });
    const byId = new Map(products.map((p) => [p.id, p]));
    return lines.map((l) => {
      const p = byId.get(l.productId);
      if (!p || !p.active) {
        throw new BadRequestException({
          code: 'MFG_PO_PRODUCT_INVALID',
          message: 'Một dòng hàng trỏ tới sản phẩm không tồn tại hoặc đã lưu trữ.',
        });
      }
      if (!(l.qty > 0) || l.unitPrice < 0) {
        throw new BadRequestException({
          code: 'MFG_PO_LINE_INVALID',
          message: 'Số lượng phải > 0 và đơn giá không âm.',
        });
      }
      return {
        productId: l.productId,
        qty: new Prisma.Decimal(round3(l.qty)),
        uomId: p.uomId,
        unitPrice: new Prisma.Decimal(roundCost(l.unitPrice)),
      };
    });
  }

  async createPurchaseOrder(dto: CreatePoDto, userId?: string) {
    const supplier = await this.prisma.mfgSupplier.findUnique({
      where: { id: dto.supplierId },
    });
    if (!supplier || !supplier.active) {
      throw new BadRequestException({
        code: 'MFG_SUPPLIER_INVALID',
        message: 'Nhà cung cấp không tồn tại hoặc đã ngừng hợp tác.',
      });
    }
    const lines = await this.validatePoLines(dto.lines);
    const count = await this.prisma.mfgPurchaseOrder.count();
    return this.prisma.mfgPurchaseOrder.create({
      data: {
        code: `PO-${String(count + 1).padStart(5, '0')}`,
        supplierId: dto.supplierId,
        expectedDate: dto.expectedDate ? new Date(dto.expectedDate) : null,
        note: dto.note,
        createdById: userId ?? null,
        lines: { create: lines },
      },
      include: ManufacturingService.PO_INCLUDE,
    });
  }

  async updatePurchaseOrder(id: string, dto: UpdatePoDto) {
    const po = await this.getPurchaseOrder(id);
    if (po.state !== 'DRAFT') {
      throw new BadRequestException({
        code: 'MFG_PO_NOT_DRAFT',
        message: 'Chỉ sửa được đơn mua ở trạng thái nháp.',
      });
    }
    const lines = dto.lines ? await this.validatePoLines(dto.lines) : null;
    return this.prisma.mfgPurchaseOrder.update({
      where: { id },
      data: {
        ...(dto.supplierId && { supplierId: dto.supplierId }),
        ...(dto.expectedDate !== undefined && {
          expectedDate: dto.expectedDate ? new Date(dto.expectedDate) : null,
        }),
        ...(dto.note !== undefined && { note: dto.note }),
        ...(lines && { lines: { deleteMany: {}, create: lines } }),
      },
      include: ManufacturingService.PO_INCLUDE,
    });
  }

  async confirmPurchaseOrder(id: string) {
    const po = await this.getPurchaseOrder(id);
    if (po.state !== 'DRAFT') {
      throw new BadRequestException({
        code: 'MFG_PO_NOT_DRAFT',
        message: 'Đơn mua đã xác nhận hoặc đã đóng.',
      });
    }
    if (po.lines.length === 0) {
      throw new BadRequestException({
        code: 'MFG_PO_LINES_EMPTY',
        message: 'Đơn mua cần ít nhất một dòng hàng.',
      });
    }
    return this.prisma.mfgPurchaseOrder.update({
      where: { id },
      data: { state: 'CONFIRMED' },
      include: ManufacturingService.PO_INCLUDE,
    });
  }

  /** Stock already received stays in stock — cancel only closes the remainder. */
  async cancelPurchaseOrder(id: string) {
    const po = await this.getPurchaseOrder(id);
    if (po.state === 'RECEIVED' || po.state === 'CANCELLED') {
      throw new BadRequestException({
        code: 'MFG_PO_CLOSED',
        message: 'Đơn mua đã đóng.',
      });
    }
    return this.prisma.mfgPurchaseOrder.update({
      where: { id },
      data: { state: 'CANCELLED' },
      include: ManufacturingService.PO_INCLUDE,
    });
  }

  /**
   * Issue stock to the shop counter for an internal transfer: STOCK → STORE,
   * valued at AVCO, FEFO across lots for lot-tracked products. Runs inside the
   * caller's transaction (the order-receipt one) so order state and stock move
   * together.
   *
   * ponytail: stock may go negative — the goods were physically delivered, so
   * the move is booked even when the ledger disagrees; negative on-hand is the
   * stocktake signal, not a reason to block the branch's receipt.
   */
  async issueForTransfer(
    db: Tx,
    args: { productId: string; qty: number; refId: string },
  ): Promise<void> {
    const qty = round3(args.qty);
    if (qty <= 0) return;
    const stock = await this.locationId(db, 'STOCK');
    const store = await this.locationId(db, 'STORE');
    const product = await db.mfgProduct.findUnique({
      where: { id: args.productId },
    });
    if (!product) throw new NotFoundException({ code: 'MFG_PRODUCT_NOT_FOUND' });

    const base = {
      productId: args.productId,
      uomId: product.uomId,
      srcLocationId: stock,
      destLocationId: store,
      refType: 'INTERNAL' as const,
      refId: args.refId,
      unitCost: n(product.avgCost),
    };

    let remaining = qty;
    if (product.tracking === 'LOT') {
      // FEFO: drain lots by earliest expiry first (no-expiry lots last).
      const quants = await db.mfgStockQuant.findMany({
        where: { productId: args.productId, locationId: stock, quantity: { gt: 0 } },
        include: { lot: true },
      });
      quants.sort((a, b) => {
        const ax = a.lot?.expiryDate?.getTime() ?? Number.MAX_SAFE_INTEGER;
        const bx = b.lot?.expiryDate?.getTime() ?? Number.MAX_SAFE_INTEGER;
        return ax - bx;
      });
      for (const q of quants) {
        if (remaining <= 0) break;
        const free = n(q.quantity) - n(q.reservedQty);
        if (free <= 0) continue;
        const take = round3(Math.min(remaining, free));
        await this.move(db, { ...base, lotId: q.lotId, qty: take });
        remaining = round3(remaining - take);
      }
    }
    if (remaining > 0) {
      await this.move(db, { ...base, lotId: null, qty: remaining });
    }
  }

  /**
   * Every goods receipt for one product, newest first — who it was bought
   * from, when, at what price, into which lot. Receipts made without a PO
   * (legacy or ad-hoc) appear with a null PO/supplier.
   */
  async purchaseHistory(productId: string) {
    const moves = await this.prisma.mfgStockMove.findMany({
      where: { productId, refType: 'RECEIPT' },
      orderBy: { date: 'desc' },
      take: 200,
      include: { lot: true, uom: true },
    });
    const poIds = [...new Set(moves.map((m) => m.refId).filter((x): x is string => !!x))];
    const pos = await this.prisma.mfgPurchaseOrder.findMany({
      where: { id: { in: poIds } },
      include: { supplier: true },
    });
    const byId = new Map(pos.map((p) => [p.id, p]));
    return moves.map((m) => {
      const po = m.refId ? byId.get(m.refId) : undefined;
      return {
        date: m.date,
        qty: n(m.qty),
        uomCode: m.uom.code,
        unitCost: n(m.unitCost),
        lotName: m.lot?.name ?? null,
        poId: po?.id ?? null,
        poCode: po?.code ?? null,
        supplierName: po?.supplier.name ?? null,
      };
    });
  }
}

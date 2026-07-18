import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

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
    uomId: string;
    unitCost: number;
    lotName?: string;
  }) {
    const product = await this.prisma.mfgProduct.findUnique({
      where: { id: dto.productId },
      include: { uom: true },
    });
    if (!product) throw new NotFoundException({ code: 'MFG_PRODUCT_NOT_FOUND' });
    if (dto.qty <= 0) {
      throw new BadRequestException({ code: 'MFG_QTY_INVALID' });
    }

    const supplier = await this.locationId(this.prisma, 'SUPPLIER');
    const stock = await this.locationId(this.prisma, 'STOCK');
    const moveUom = await this.prisma.mfgUom.findUnique({ where: { id: dto.uomId } });
    if (!moveUom) throw new BadRequestException({ code: 'MFG_UOM_NOT_FOUND' });

    const baseQty = toBase(dto.qty, uomLike(moveUom));

    return this.prisma.$transaction(async (db) => {
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
        unitCost: dto.unitCost,
      });
      await db.mfgProduct.update({
        where: { id: dto.productId },
        data: { avgCost: newAvg },
      });
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
      include: { lines: true, product: true },
    });
    if (!bom) throw new NotFoundException({ code: 'MFG_BOM_NOT_FOUND' });
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
      const avail = await this.availableAtStock(this.prisma, c.productId, stock);
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
   * Reserve available stock against the MO's components (FIFO across lots by
   * expiry). Reserves whatever is on hand up to what's needed — a short
   * component reserves what it can and stays Not-available.
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
          if (reserved === 1) remaining -= take;
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
          const take = Math.min(n(q.quantity), remaining);
          if (take <= 0) continue;
          await this.move(db, {
            productId: c.productId,
            lotId: q.lotId,
            qty: take,
            uomId: c.product.uomId,
            srcLocationId: stock,
            destLocationId: production,
            refType: 'MO',
            refId: mo.id,
            unitCost: n(c.product.avgCost),
          });
          // Release any reservation we held on this quant — atomic decrement,
          // clamped by what the loaded row holds so it never goes negative.
          if (n(q.reservedQty) > 0) {
            await db.mfgStockQuant.update({
              where: { id: q.id },
              data: { reservedQty: { decrement: round3(Math.min(take, n(q.reservedQty))) } },
            });
          }
          remaining -= take;
        }
        // Backflush the shortfall so cost/qty stay whole (quant goes negative).
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

      // Release any reservations this MO's components hold.
      const stock = await this.locationId(db, 'STOCK');
      const comps = await db.mfgOrderComponent.findMany({ where: { moId: id } });
      for (const c of comps) {
        if (n(c.reservedQty) <= 0) continue;
        let remaining = n(c.reservedQty);
        const quants = await db.mfgStockQuant.findMany({
          where: { productId: c.productId, locationId: stock, reservedQty: { gt: 0 } },
        });
        for (const q of quants) {
          if (remaining <= 0) break;
          const give = Math.min(n(q.reservedQty), remaining);
          await db.mfgStockQuant.update({
            where: { id: q.id },
            data: { reservedQty: { decrement: round3(give) } },
          });
          remaining -= give;
        }
        await db.mfgOrderComponent.update({
          where: { id: c.id },
          data: { reservedQty: 0 },
        });
      }
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
    uomId: string;
    reason: string;
    lotId?: string;
    moId?: string;
  }) {
    if (dto.qty <= 0) throw new BadRequestException({ code: 'MFG_QTY_INVALID' });
    const product = await this.prisma.mfgProduct.findUnique({
      where: { id: dto.productId },
    });
    if (!product) throw new NotFoundException({ code: 'MFG_PRODUCT_NOT_FOUND' });
    const uom = await this.prisma.mfgUom.findUnique({ where: { id: dto.uomId } });
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
          uomId: dto.uomId,
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
      include: { product: true, lot: true, location: true },
    });
  }

  expiringLots(beforeIso: string) {
    return this.prisma.mfgLot.findMany({
      where: { expiryDate: { not: null, lte: new Date(beforeIso) } },
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

  listProducts(type?: string) {
    return this.prisma.mfgProduct.findMany({
      where: { active: true, ...(type ? { type: type as never } : {}) },
      include: { category: true, uom: true },
      orderBy: { code: 'asc' },
    });
  }

  listBoms() {
    return this.prisma.mfgBom.findMany({
      where: { active: true },
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

  /** Dashboard counts — MOs grouped by state. */
  async moStateCounts() {
    const rows = await this.prisma.mfgOrder.groupBy({
      by: ['state'],
      _count: { _all: true },
    });
    return rows.map((r) => ({ state: r.state, count: r._count._all }));
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
}

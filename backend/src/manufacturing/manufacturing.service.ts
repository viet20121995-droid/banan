import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

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
    const existing = await db.mfgStockQuant.findFirst({
      where: {
        productId: args.productId,
        lotId: args.lotId,
        locationId: args.locationId,
      },
    });
    if (existing) {
      await db.mfgStockQuant.update({
        where: { id: existing.id },
        data: {
          quantity: round3(n(existing.quantity) + (args.dQty ?? 0)),
          reservedQty: round3(n(existing.reservedQty) + (args.dReserved ?? 0)),
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
    const code = await this.nextMoCode(this.prisma);

    return this.prisma.mfgOrder.create({
      data: {
        code,
        productId: bom.productId,
        bomId: bom.id,
        qtyToProduce: round3(dto.qtyToProduce),
        uomId: bom.uomId,
        scheduledDate: dto.scheduledDate ? new Date(dto.scheduledDate) : null,
        responsibleId: dto.responsibleId,
        components: {
          create: bom.lines.map((l) => ({
            productId: l.componentId,
            qtyToConsume: round3(n(l.qty) * factor),
            uomId: l.uomId,
          })),
        },
      },
      include: { components: true },
    });
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
    const mo = await this.prisma.mfgOrder.findUnique({
      where: { id },
      include: { components: true },
    });
    if (!mo) throw new NotFoundException({ code: 'MFG_MO_NOT_FOUND' });
    const stock = await this.locationId(this.prisma, 'STOCK');

    await this.prisma.$transaction(async (db) => {
      for (const c of mo.components) {
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
          const take = Math.min(free, remaining);
          await db.mfgStockQuant.update({
            where: { id: q.id },
            data: { reservedQty: round3(n(q.reservedQty) + take) },
          });
          remaining -= take;
        }
        await db.mfgOrderComponent.update({
          where: { id: c.id },
          data: { reservedQty: round3(n(c.qtyToConsume) - remaining) },
        });
      }
      await db.mfgOrder.update({
        where: { id: mo.id },
        data: { state: mo.state === 'CONFIRMED' ? 'PROGRESS' : mo.state },
      });
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
  async produce(id: string, producedQty?: number) {
    const stock = await this.locationId(this.prisma, 'STOCK');
    const production = await this.locationId(this.prisma, 'PRODUCTION');

    const mo = await this.prisma.mfgOrder.findUnique({
      where: { id },
      include: {
        product: { include: { uom: true } },
        components: { include: { product: true, uom: true } },
        workOrders: { include: { workCenter: true } },
      },
    });
    if (!mo) throw new NotFoundException({ code: 'MFG_MO_NOT_FOUND' });
    if (mo.state === 'DONE' || mo.state === 'CANCEL') {
      throw new ConflictException({
        code: 'MFG_MO_STATE',
        message: `MO đã ${mo.state === 'DONE' ? 'hoàn tất' : 'huỷ'}.`,
      });
    }
    const outQty = producedQty ?? n(mo.qtyToProduce);
    if (outQty <= 0) throw new BadRequestException({ code: 'MFG_QTY_INVALID' });

    return this.prisma.$transaction(async (db) => {
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
          // Release any reservation we held on this quant.
          if (n(q.reservedQty) > 0) {
            await db.mfgStockQuant.update({
              where: { id: q.id },
              data: {
                reservedQty: round3(Math.max(0, n(q.reservedQty) - take)),
              },
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
    if (mo.state === 'DONE') {
      throw new ConflictException({
        code: 'MFG_MO_STATE',
        message: 'Không thể huỷ MO đã hoàn tất.',
      });
    }
    // Release any reservations this MO holds.
    await this.prisma.$transaction(async (db) => {
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
            data: { reservedQty: round3(n(q.reservedQty) - give) },
          });
          remaining -= give;
        }
        await db.mfgOrderComponent.update({
          where: { id: c.id },
          data: { reservedQty: 0 },
        });
      }
      await db.mfgOrder.update({ where: { id }, data: { state: 'CANCEL' } });
      await db.mfgWorkOrder.updateMany({
        where: { moId: id, state: { notIn: ['DONE', 'CANCEL'] } },
        data: { state: 'CANCEL' },
      });
    });
    return { id, state: 'CANCEL' };
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
        product: true,
        bom: true,
        components: { include: { product: true } },
        workOrders: { include: { workCenter: true, bomOperation: true } },
      },
    });
  }
}

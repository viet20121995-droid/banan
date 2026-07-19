import { PrismaClient } from '@prisma/client';

import { seedManufacturing } from '../../prisma/seed-manufacturing';

import { ManufacturingSchedulerService } from './manufacturing-scheduler.service';
import { ManufacturingService } from './manufacturing.service';

/**
 * End-to-end golden path against a REAL Postgres — the acceptance criteria you
 * can't prove with mocks: receive → cost rollup → check availability → reserve →
 * produce (lot + expiry + stock + AVCO) → scrap → traceability, with every
 * number hand-checked.
 *
 * Gated on MFG_IT so the default `npx jest` (no DB) stays green. Run with:
 *   MFG_IT=1 DATABASE_URL=postgresql://... npx jest manufacturing.integration
 */
const RUN = process.env.MFG_IT === '1' && !!process.env.DATABASE_URL;
const d = RUN ? describe : describe.skip;

d('Manufacturing golden path (integration)', () => {
  const prisma = new PrismaClient();
  // The service only touches prisma.* delegates + $transaction, both present on
  // PrismaClient, so a plain client stands in for the Nest PrismaService.
  const mfg = new ManufacturingService(prisma as never);
  // A stub NotificationsService that records what the scheduler would push.
  const notifyCalls: Array<{ type: string; body: string }> = [];
  const scheduler = new ManufacturingSchedulerService(
    prisma as never,
    {
      notifyKitchenRoles: async (t: { type: string; body: string }) => {
        notifyCalls.push({ type: t.type, body: t.body });
      },
    } as never,
  );

  let ids: Awaited<ReturnType<typeof seedManufacturing>>['ids'];
  let gUom: string;

  beforeAll(async () => {
    // Clean slate — order matters for FKs.
    await prisma.mfgReservation.deleteMany();
    await prisma.mfgMaintenance.deleteMany();
    await prisma.mfgStockMove.deleteMany();
    await prisma.mfgStockQuant.deleteMany();
    await prisma.mfgScrap.deleteMany();
    await prisma.mfgWorkOrder.deleteMany();
    await prisma.mfgOrderComponent.deleteMany();
    await prisma.mfgOrder.deleteMany();
    await prisma.mfgLot.deleteMany();
    await prisma.mfgBomLine.deleteMany();
    await prisma.mfgBomOperation.deleteMany();
    await prisma.mfgBomByproduct.deleteMany();
    await prisma.mfgBom.deleteMany();
    await prisma.mfgProduct.deleteMany();
    await prisma.mfgWorkCenter.deleteMany();
    await prisma.mfgCategory.deleteMany();
    await prisma.mfgLocation.deleteMany();
    await prisma.mfgUom.deleteMany();

    const seeded = await seedManufacturing(prisma);
    ids = seeded.ids;
    gUom = seeded.g;
  });

  afterAll(() => prisma.$disconnect());

  const onHand = async (productId: string) => {
    const stock = await prisma.mfgLocation.findUniqueOrThrow({ where: { code: 'STOCK' } });
    const q = await prisma.mfgStockQuant.findMany({ where: { productId, locationId: stock.id } });
    return q.reduce((s, r) => s + Number(r.quantity), 0);
  };
  const bomOf = (productId: string) =>
    prisma.mfgBom.findFirstOrThrow({ where: { productId, active: true } });

  it('receives raw materials and rolls AVCO', async () => {
    await mfg.receive({ productId: ids.flour, qty: 2000, uomId: gUom, unitCost: 30 });
    await mfg.receive({ productId: ids.sugar, qty: 2000, uomId: gUom, unitCost: 25 });
    await mfg.receive({ productId: ids.egg, qty: 2000, uomId: gUom, unitCost: 35 });
    await mfg.receive({ productId: ids.cream, qty: 1000, uomId: gUom, unitCost: 120 });
    await mfg.receive({ productId: ids.berry, qty: 500, uomId: gUom, unitCost: 200 });

    const flour = await prisma.mfgProduct.findUniqueOrThrow({ where: { id: ids.flour } });
    expect(Number(flour.avgCost)).toBe(30);
    expect(await onHand(ids.flour)).toBe(2000);
  });

  it('produces the semi (sponge): lot, expiry, stock, cost = materials + ops', async () => {
    const bom = await bomOf(ids.sponge);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(mo.id);
    const done = await mfg.produce(mo.id);

    // material = 500*30 + 350*25 + 400*35 = 37750
    // ops = 15/60*60000 + 20/60*120000 + 35/60*150000 = 142500
    expect(Number(done.totalCost)).toBe(180250);
    expect(done.cost.materialCost).toBe(37750);
    expect(done.cost.operationCost).toBe(142500);

    // lot with today's mfg date + 3-day expiry
    const lot = await prisma.mfgLot.findUniqueOrThrow({ where: { id: done.lotId! } });
    const days = Math.round((lot.expiryDate!.getTime() - lot.mfgDate.getTime()) / 86400000);
    expect(days).toBe(3);

    expect(await onHand(ids.sponge)).toBe(1000);
    // AVCO for the semi keeps 2 decimals so the cake rollup stays exact.
    const sponge = await prisma.mfgProduct.findUniqueOrThrow({ where: { id: ids.sponge } });
    expect(Number(sponge.avgCost)).toBe(180.25);
  });

  it('flags availability from live stock', async () => {
    const bom = await bomOf(ids.cake);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    const avail = await mfg.confirmMO(mo.id); // confirm runs check-availability
    for (const c of avail.components) expect(c.status).toBe('AVAILABLE');
    (globalThis as Record<string, unknown>).__cakeMo = mo.id;
  });

  it('produces the finished cake through a multi-level BoM; cost matches by hand', async () => {
    const moId = (globalThis as Record<string, unknown>).__cakeMo as string;
    await mfg.reserve(moId);
    const done = await mfg.produce(moId);

    // material = 600*180.25 + 300*120 + 100*200 = 164150
    // ops = 10/60*70000 + 25/60*80000 = 45000
    expect(done.cost.materialCost).toBe(164150);
    expect(done.cost.operationCost).toBe(45000);
    expect(Number(done.totalCost)).toBe(209150);

    // finished stock in, component stock down
    expect(await onHand(ids.cake)).toBe(1000);
    expect(await onHand(ids.sponge)).toBe(400); // 1000 - 600
    expect(await onHand(ids.cream)).toBe(700); // 1000 - 300
    expect(await onHand(ids.berry)).toBe(400); // 500 - 100

    const cakeLot = await prisma.mfgLot.findUniqueOrThrow({ where: { id: done.lotId! } });
    const days = Math.round((cakeLot.expiryDate!.getTime() - cakeLot.mfgDate.getTime()) / 86400000);
    expect(days).toBe(2);
  });

  it('scrap reduces stock', async () => {
    const before = await onHand(ids.cake);
    await mfg.scrap({ productId: ids.cake, qty: 200, uomId: gUom, reason: 'Rơi vỡ' });
    expect(await onHand(ids.cake)).toBe(before - 200);
  });

  it('traces a finished lot back to its raw lots', async () => {
    const cakeLot = await prisma.mfgLot.findFirstOrThrow({
      where: { productId: ids.cake },
      orderBy: { createdAt: 'desc' },
    });
    const trace = await mfg.traceLot(cakeLot.id);

    expect(trace.product).toBe('FIN-STRAWCAKE');
    const codes = trace.consumed.map((c) => (c as { product: string }).product);
    expect(codes).toEqual(expect.arrayContaining(['SEMI-SPONGE', 'RAW-CREAM', 'RAW-STRAW']));

    // the consumed sponge recurses into its own raw lots
    const spongeEntry = trace.consumed.find(
      (c) => (c as { product: string }).product === 'SEMI-SPONGE',
    ) as { trace?: { consumed: { product: string }[] } };
    const rawCodes = spongeEntry.trace!.consumed.map((c) => c.product);
    expect(rawCodes).toEqual(expect.arrayContaining(['RAW-FLOUR', 'RAW-SUGAR', 'RAW-EGG']));
  });

  // ── shop floor + QC (increment 3) ──
  it('gates a work order on its quality check, and records the fail as an alert', async () => {
    // A fresh sponge MO, confirmed → its work orders are READY.
    const bom = await bomOf(ids.sponge);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 500 });
    await mfg.confirmMO(mo.id);
    const wo = await prisma.mfgWorkOrder.findFirstOrThrow({
      where: { moId: mo.id },
      orderBy: { sequence: 'asc' },
      include: { bomOperation: true },
    });

    // A HACCP-style temperature check on that operation: 36–40°C.
    const qp = await mfg.createQualityPoint({
      titleVi: 'Nhiệt độ hỗn hợp trứng-sữa',
      titleEn: 'Egg-milk mixture temp',
      testType: 'MEASURE',
      bomOperationId: wo.bomOperationId,
      normMin: 36,
      normMax: 40,
      unit: '°C',
    });

    await mfg.startWO(wo.id);

    // No check yet → can't finish.
    await expect(mfg.doneWO(wo.id)).rejects.toThrow(/kiểm tra/i);

    // Out of range → FAIL, an alert opens, still blocked.
    await mfg.recordCheck({ qualityPointId: qp.id, workOrderId: wo.id, measuredValue: 50 });
    const alerts = await mfg.listAlerts();
    expect(alerts.some((a) => a.moId === mo.id)).toBe(true);
    await expect(mfg.doneWO(wo.id)).rejects.toThrow(/KHÔNG đạt/);

    // Re-measure in range → PASS supersedes, and now it finishes with time banked.
    await mfg.recordCheck({ qualityPointId: qp.id, workOrderId: wo.id, measuredValue: 38 });
    const finished = await mfg.doneWO(wo.id);
    expect(finished.state).toBe('DONE');
    expect(finished.dateFinished).not.toBeNull();
  });

  // ── planning: schedule + employee assignment (increment 4) ──
  it('schedules an MO with an assignee, clears it back to the backlog, and refuses a finished MO', async () => {
    // A kitchen user to assign (idempotent by email so reruns don't collide).
    const boss = await prisma.user.upsert({
      where: { email: 'mfg-it-planner@banan.test' },
      update: {},
      create: {
        email: 'mfg-it-planner@banan.test',
        passwordHash: 'x',
        fullName: 'Chị Kế Hoạch',
        role: 'KITCHEN_MANAGER',
      },
    });

    const bom = await bomOf(ids.sponge);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 200 });

    // Assign to a day + the planner, and confirm schedule() resolves the name.
    const when = new Date('2026-08-01T00:00:00.000Z');
    await mfg.planMO(mo.id, { scheduledDate: when.toISOString(), responsibleId: boss.id });
    let row = (await mfg.schedule()).find((r) => r.id === mo.id)!;
    expect(row.scheduledDate?.toISOString()).toBe(when.toISOString());
    expect(row.responsibleName).toBe('Chị Kế Hoạch');

    // Clear only the date → back in the backlog, assignee retained.
    await mfg.planMO(mo.id, { scheduledDate: null });
    row = (await mfg.schedule()).find((r) => r.id === mo.id)!;
    expect(row.scheduledDate).toBeNull();
    expect(row.responsibleId).toBe(boss.id);

    // The finished cake MO (produced earlier) can't be rescheduled.
    const cakeMo = (globalThis as Record<string, unknown>).__cakeMo as string;
    await expect(mfg.planMO(cakeMo, { scheduledDate: when.toISOString() })).rejects.toThrow(
      /kết thúc/,
    );

    // A non-kitchen account can't be assigned as responsible.
    const outsider = await prisma.user.upsert({
      where: { email: 'mfg-it-customer@banan.test' },
      update: { role: 'CUSTOMER', isActive: true },
      create: {
        email: 'mfg-it-customer@banan.test',
        passwordHash: 'x',
        fullName: 'Khách Lạ',
        role: 'CUSTOMER',
      },
    });
    const mo2 = await mfg.createMO({ bomId: bom.id, qtyToProduce: 100 });
    await expect(mfg.planMO(mo2.id, { responsibleId: outsider.id })).rejects.toThrow(/nhân sự bếp/);
  });

  // The direct produce() path must honour the QC gate, not just shop-floor doneWO.
  it('produce enforces the operation QC gate (not just doneWO)', async () => {
    const bom = await bomOf(ids.sponge);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 300 });
    await mfg.confirmMO(mo.id);
    const wo = await prisma.mfgWorkOrder.findFirstOrThrow({
      where: { moId: mo.id },
      orderBy: { sequence: 'asc' },
      include: { bomOperation: true },
    });
    // Guarantee at least one active QC point on the operation.
    await mfg.createQualityPoint({
      titleVi: 'Nhiệt độ nướng',
      titleEn: 'Bake temp',
      testType: 'MEASURE',
      bomOperationId: wo.bomOperationId,
      normMin: 150,
      normMax: 180,
      unit: '°C',
    });

    // Direct produce must refuse while a QC point on the op is unchecked.
    await expect(mfg.produce(mo.id)).rejects.toThrow(/kiểm tra|đạt/i);

    // Record a passing check for every active point on this WO → produce runs.
    const points = await prisma.mfgQualityPoint.findMany({
      where: { bomOperationId: wo.bomOperationId, active: true },
    });
    for (const p of points) {
      await mfg.recordCheck({
        qualityPointId: p.id,
        workOrderId: wo.id,
        measuredValue: p.testType === 'MEASURE' ? Number(p.normMin ?? 0) : undefined,
        passFail: p.testType === 'PASS_FAIL' ? 'PASS' : undefined,
      });
    }
    const done = await mfg.produce(mo.id);
    expect(done.state).toBe('DONE');
  });

  // ── concurrency (round-2 review) ──
  it('produce is race-safe: two concurrent calls on one MO book stock once', async () => {
    // Cake operations carry no QC points, so the produce QC gate is vacuous here
    // and can't mask the concurrency behaviour. Stock its components directly.
    await mfg.receive({ productId: ids.sponge, qty: 5000, uomId: gUom, unitCost: 180.25 });
    await mfg.receive({ productId: ids.cream, qty: 5000, uomId: gUom, unitCost: 120 });
    await mfg.receive({ productId: ids.berry, qty: 5000, uomId: gUom, unitCost: 200 });
    const bom = await bomOf(ids.cake);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(mo.id);

    const before = await onHand(ids.cake);
    const results = await Promise.allSettled([mfg.produce(mo.id), mfg.produce(mo.id)]);
    const ok = results.filter((r) => r.status === 'fulfilled').length;
    const failed = results.filter((r) => r.status === 'rejected').length;
    expect(ok).toBe(1);
    expect(failed).toBe(1);
    // Finished stock booked exactly once (+1000), not twice.
    expect(await onHand(ids.cake)).toBe(before + 1000);
  });

  it('reserve never overbooks a quant when two MOs compete for it', async () => {
    const stockLoc = await prisma.mfgLocation.findUniqueOrThrow({ where: { code: 'STOCK' } });
    // Pin egg to a single known quant with only 300 on hand — less than the 400
    // each sponge MO wants, so the two reserves genuinely contend.
    await prisma.mfgStockQuant.deleteMany({
      where: { productId: ids.egg, locationId: stockLoc.id },
    });
    await prisma.mfgStockQuant.create({
      data: {
        productId: ids.egg,
        lotId: null,
        locationId: stockLoc.id,
        quantity: 300,
        reservedQty: 0,
      },
    });

    const bom = await bomOf(ids.sponge);
    const moA = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 }); // egg 400
    const moB = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(moA.id);
    await mfg.confirmMO(moB.id);

    await Promise.allSettled([mfg.reserve(moA.id), mfg.reserve(moB.id)]);

    // The invariant that must never break: reservedQty <= quantity per quant.
    const eggQuants = await prisma.mfgStockQuant.findMany({
      where: { productId: ids.egg, locationId: stockLoc.id },
    });
    const totalRes = eggQuants.reduce((s, q) => s + Number(q.reservedQty), 0);
    const totalQty = eggQuants.reduce((s, q) => s + Number(q.quantity), 0);
    expect(totalRes).toBeLessThanOrEqual(totalQty + 1e-9);
  });

  // ── state guards (round-3 review) ──
  it('produce refuses a DRAFT MO (must be confirmed first)', async () => {
    const bom = await bomOf(ids.sponge);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 100 }); // DRAFT
    await expect(mfg.produce(mo.id)).rejects.toThrow(/xác nhận/i);
    const still = await prisma.mfgOrder.findUniqueOrThrow({ where: { id: mo.id } });
    expect(still.state).toBe('DRAFT'); // untouched, nothing booked
  });

  it('produce vs cancel race: exactly one wins and the state stays consistent', async () => {
    // Cake ops carry no QC points; stock its components so produce can run.
    await mfg.receive({ productId: ids.sponge, qty: 5000, uomId: gUom, unitCost: 180.25 });
    await mfg.receive({ productId: ids.cream, qty: 5000, uomId: gUom, unitCost: 120 });
    await mfg.receive({ productId: ids.berry, qty: 5000, uomId: gUom, unitCost: 200 });
    const bom = await bomOf(ids.cake);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(mo.id);
    const before = await onHand(ids.cake);

    const [pr, cr] = await Promise.allSettled([mfg.produce(mo.id), mfg.cancelMO(mo.id)]);
    const finalMo = await prisma.mfgOrder.findUniqueOrThrow({ where: { id: mo.id } });

    // The two outcomes are mutually exclusive; stock is booked iff produce won.
    if (finalMo.state === 'DONE') {
      expect(pr.status).toBe('fulfilled');
      expect(cr.status).toBe('rejected');
      expect(await onHand(ids.cake)).toBe(before + 1000);
    } else {
      expect(finalMo.state).toBe('CANCEL');
      expect(cr.status).toBe('fulfilled');
      expect(pr.status).toBe('rejected');
      expect(await onHand(ids.cake)).toBe(before);
    }
  });

  it('two concurrent cancels are idempotent and never drive reservedQty negative', async () => {
    const bom = await bomOf(ids.cake);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(mo.id);
    await mfg.reserve(mo.id); // take some holds

    await Promise.allSettled([mfg.cancelMO(mo.id), mfg.cancelMO(mo.id)]);

    const finalMo = await prisma.mfgOrder.findUniqueOrThrow({ where: { id: mo.id } });
    expect(finalMo.state).toBe('CANCEL');
    // A double release would push a quant below zero; the claim prevents it.
    const quants = await prisma.mfgStockQuant.findMany();
    for (const q of quants) expect(Number(q.reservedQty)).toBeGreaterThanOrEqual(0);
  });

  // ── reserve idempotency + state guard (round-4 review) ──
  it('reserve is idempotent under two concurrent calls on the same MO', async () => {
    const stockLoc = await prisma.mfgLocation.findUniqueOrThrow({ where: { code: 'STOCK' } });
    // Pin flour to one clean quant with ample stock so a double hold (not just an
    // overbook) would show — both reserves could otherwise each grab 500.
    await prisma.mfgStockQuant.deleteMany({
      where: { productId: ids.flour, locationId: stockLoc.id },
    });
    await prisma.mfgStockQuant.create({
      data: {
        productId: ids.flour,
        lotId: null,
        locationId: stockLoc.id,
        quantity: 5000,
        reservedQty: 0,
      },
    });

    const bom = await bomOf(ids.sponge);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 }); // flour 500
    await mfg.confirmMO(mo.id);

    await Promise.allSettled([mfg.reserve(mo.id), mfg.reserve(mo.id)]);

    // The flour held on the quant must match the component's reserved — 500, not
    // 1000. A non-idempotent reserve double-holds the quant and strands 500.
    const flourComp = await prisma.mfgOrderComponent.findFirstOrThrow({
      where: { moId: mo.id, productId: ids.flour },
    });
    const flourQuants = await prisma.mfgStockQuant.findMany({
      where: { productId: ids.flour, locationId: stockLoc.id },
    });
    const quantReserved = flourQuants.reduce((s, q) => s + Number(q.reservedQty), 0);
    expect(Number(flourComp.reservedQty)).toBe(500);
    expect(quantReserved).toBe(500);
  });

  it('reserve refuses a DRAFT or terminal MO', async () => {
    const bom = await bomOf(ids.sponge);
    const draft = await mfg.createMO({ bomId: bom.id, qtyToProduce: 100 }); // DRAFT
    await expect(mfg.reserve(draft.id)).rejects.toThrow(/xác nhận/i);

    const cancelled = await mfg.createMO({ bomId: bom.id, qtyToProduce: 100 });
    await mfg.confirmMO(cancelled.id);
    await mfg.cancelMO(cancelled.id);
    await expect(mfg.reserve(cancelled.id)).rejects.toThrow(/huỷ/i);
  });

  // ── work-order transition concurrency (preempt review) ──
  it('two concurrent doneWO finish the work order exactly once', async () => {
    const bom = await bomOf(ids.cake); // cake ops carry no QC points → not gated
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 100 });
    await mfg.confirmMO(mo.id);
    const wo = await prisma.mfgWorkOrder.findFirstOrThrow({
      where: { moId: mo.id },
      orderBy: { sequence: 'asc' },
    });
    await mfg.startWO(wo.id);

    const results = await Promise.allSettled([mfg.doneWO(wo.id), mfg.doneWO(wo.id)]);
    // The guarded UPDATE re-checks state under the row lock: one claims DONE, the
    // other sees it already terminal and is rejected. No double-close.
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(results.filter((r) => r.status === 'rejected')).toHaveLength(1);
    const final = await prisma.mfgWorkOrder.findUniqueOrThrow({ where: { id: wo.id } });
    expect(final.state).toBe('DONE');
  });

  it('pause banks run time incrementally from the row dateStart, across resumes', async () => {
    const bom = await bomOf(ids.cake);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 100 });
    await mfg.confirmMO(mo.id);
    const wo = await prisma.mfgWorkOrder.findFirstOrThrow({
      where: { moId: mo.id },
      orderBy: { sequence: 'asc' },
    });

    // First run: pretend it started 10 minutes ago, then pause.
    await prisma.mfgWorkOrder.update({
      where: { id: wo.id },
      data: { state: 'PROGRESS', dateStart: new Date(Date.now() - 10 * 60000), durationReal: 0 },
    });
    const paused1 = await mfg.pauseWO(wo.id);
    expect(paused1.state).toBe('READY');
    expect(paused1.dateStart).toBeNull();
    expect(paused1.durationReal).toBeGreaterThanOrEqual(9);
    expect(paused1.durationReal).toBeLessThanOrEqual(11);

    // Second run: 5 more minutes → banked on TOP of the first (increment, not overwrite).
    await prisma.mfgWorkOrder.update({
      where: { id: wo.id },
      data: { state: 'PROGRESS', dateStart: new Date(Date.now() - 5 * 60000) },
    });
    const paused2 = await mfg.pauseWO(wo.id);
    expect(paused2.durationReal).toBeGreaterThanOrEqual(paused1.durationReal + 4);
  });

  // ── reports + replenishment (increment 5) ──
  it('production and cost reports aggregate DONE MOs; the material/operation split sums to total', async () => {
    // Production report over all time — the golden-path sponge + cake are DONE.
    const prod = await mfg.productionReport();
    const spongeRow = prod.rows.find((r) => r.productId === ids.sponge);
    const cakeRow = prod.rows.find((r) => r.productId === ids.cake);
    expect(spongeRow).toBeDefined();
    expect(cakeRow).toBeDefined();
    expect(spongeRow!.totalCost).toBeGreaterThan(0);
    // Grouping loses no MO: per-product moCount sums back to the total.
    expect(prod.rows.reduce((s, r) => s + r.moCount, 0)).toBe(prod.totals.moCount);

    // Cost report: every row's split reconstructs the snapshot exactly.
    const cost = await mfg.costReport();
    for (const r of cost.rows) {
      expect(r.materialCost + r.operationCost).toBe(r.totalCost);
    }
    // The golden sponge MO (total 180250) splits into the hand-checked figures.
    const golden = cost.rows.find((r) => r.totalCost === 180250);
    expect(golden).toBeDefined();
    expect(golden!.materialCost).toBe(37750);
    expect(golden!.operationCost).toBe(142500);
  });

  it('scrap report values events at the frozen move cost, grouped by reason and product', async () => {
    const scrap = await mfg.scrapReport();
    // The golden-path scrap: 200 cake @ AVCO 209.15 frozen on the move = 41830đ.
    const byReason = scrap.byReason.find((r) => r.reason === 'Rơi vỡ');
    expect(byReason).toBeDefined();
    expect(byReason!.value).toBe(41830);
    const byProduct = scrap.byProduct.find((r) => r.productId === ids.cake);
    expect(byProduct).toBeDefined();
    expect(byProduct!.qty).toBe(200);
    expect(byProduct!.value).toBe(41830);
    expect(scrap.totals.value).toBeGreaterThanOrEqual(41830);
  });

  it('replenishment flags a raw-material shortfall from open-MO demand vs free stock', async () => {
    const stockLoc = await prisma.mfgLocation.findUniqueOrThrow({ where: { code: 'STOCK' } });
    // Zero flour on hand so demand from open MOs shows as a clean shortfall.
    await prisma.mfgStockQuant.deleteMany({
      where: { productId: ids.flour, locationId: stockLoc.id },
    });
    const bom = await bomOf(ids.sponge);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 }); // flour 500
    await mfg.confirmMO(mo.id); // open (CONFIRMED) → counts toward demand

    const rep = await mfg.replenishment();
    const flourProduct = await prisma.mfgProduct.findUniqueOrThrow({ where: { id: ids.flour } });
    const row = rep.rows.find((r) => r.productId === ids.flour);
    expect(row).toBeDefined();
    expect(row!.available).toBe(0); // stock zeroed
    expect(row!.shortfall).toBe(row!.demand); // nothing free → buy the whole demand
    expect(row!.shortfall).toBeGreaterThanOrEqual(500); // at least this MO's need
    expect(row!.avgCost).toBe(Number(flourProduct.avgCost));
    expect(row!.estCost).toBe(Math.round(row!.shortfall * row!.avgCost));
  });

  // ── increment-5 review fixes ──
  it('replenishment counts reserved stock as on-hand — no re-buy after reserve()', async () => {
    const stockLoc = await prisma.mfgLocation.findUniqueOrThrow({ where: { code: 'STOCK' } });
    // Isolate flour demand: cancel every still-open MO left by earlier tests.
    const open = await prisma.mfgOrder.findMany({
      where: { state: { in: ['DRAFT', 'CONFIRMED', 'PROGRESS'] } },
    });
    for (const m of open) await mfg.cancelMO(m.id);
    // Exactly enough flour on hand for one sponge MO, then reserve all of it.
    await prisma.mfgStockQuant.deleteMany({
      where: { productId: ids.flour, locationId: stockLoc.id },
    });
    await prisma.mfgStockQuant.create({
      data: {
        productId: ids.flour,
        lotId: null,
        locationId: stockLoc.id,
        quantity: 500,
        reservedQty: 0,
      },
    });
    const bom = await bomOf(ids.sponge);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 }); // flour 500
    await mfg.confirmMO(mo.id);
    await mfg.reserve(mo.id); // reserves all 500g flour

    // 500 need vs 500 gross on-hand → shortfall 0, even fully reserved. The old
    // net-free-stock formula returned 500 here (double-counting the reservation).
    const rep = await mfg.replenishment();
    expect(rep.rows.find((r) => r.productId === ids.flour)).toBeUndefined();
  });

  it('scrap report values a kg-entered scrap from its base-gram quantity', async () => {
    const kg = await prisma.mfgUom.findFirstOrThrow({ where: { code: 'kg' } });
    await mfg.receive({ productId: ids.flour, qty: 3000, uomId: gUom, unitCost: 10 });
    const flour = await prisma.mfgProduct.findUniqueOrThrow({ where: { id: ids.flour } });
    const unit = Number(flour.avgCost); // đồng per gram, frozen onto the scrap move
    await mfg.scrap({ productId: ids.flour, qty: 1, uomId: kg.id, reason: 'Ẩm mốc' });

    const rep = await mfg.scrapReport();
    // 1 kg = 1000 g × unit cost — NOT 1 × unit (the pre-fix mis-valuation).
    const byReason = rep.byReason.find((r) => r.reason === 'Ẩm mốc');
    expect(byReason).toBeDefined();
    expect(byReason!.value).toBe(Math.round(1000 * unit));
    const byProduct = rep.byProduct.find((r) => r.productId === ids.flour);
    expect(byProduct!.qty).toBe(1000); // base grams, matching the g uom label
  });

  // ── increment 6: scheduler jobs (HSD/overdue digest + QC-alert sweep) ──
  it('QC-alert sweep notifies each new alert once and stamps notifiedAt', async () => {
    const alert = await prisma.mfgQualityAlert.create({
      data: { title: 'Test — nhiệt độ lò vượt ngưỡng', stage: 'NEW' },
    });
    notifyCalls.length = 0;
    await scheduler.qcAlertSweep();
    expect(notifyCalls.some((c) => c.type === 'mfg.qc_alert')).toBe(true);
    const after = await prisma.mfgQualityAlert.findUniqueOrThrow({ where: { id: alert.id } });
    expect(after.notifiedAt).not.toBeNull();

    // A second sweep re-notifies nothing (notifiedAt is set).
    notifyCalls.length = 0;
    await scheduler.qcAlertSweep();
    expect(notifyCalls.length).toBe(0);
  });

  it('daily digest notifies when an MO is overdue', async () => {
    const bom = await bomOf(ids.sponge);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 100 });
    await mfg.confirmMO(mo.id);
    // Backdate its schedule to yesterday → overdue while still open.
    await prisma.mfgOrder.update({
      where: { id: mo.id },
      data: { scheduledDate: new Date(Date.now() - 86400000) },
    });
    notifyCalls.length = 0;
    await scheduler.dailyDigest();
    expect(notifyCalls.some((c) => c.type === 'mfg.daily_digest' && /quá hạn/.test(c.body))).toBe(
      true,
    );
  });

  // ── increment 7: BoM authoring ──
  it('createBom saves a new active version, derives ratio %, and retires the old one', async () => {
    const before = await bomOf(ids.sponge);
    const wc = await prisma.mfgWorkCenter.findFirstOrThrow();
    const created = await mfg.createBom({
      productId: ids.sponge,
      outputQty: 1000,
      uomId: gUom,
      lines: [
        { componentId: ids.flour, qty: 600, uomId: gUom },
        { componentId: ids.sugar, qty: 400, uomId: gUom },
      ],
      operations: [{ nameVi: 'Trộn', nameEn: 'Mix', workCenterId: wc.id, durationMinutes: 15 }],
    });

    expect(created.active).toBe(true);
    expect(created.version).toBeGreaterThan(before.version);
    expect(created.lines).toHaveLength(2);
    // Ratio vs total base weight: flour 600/1000 = 60%.
    const flourLine = created.lines.find((l) => l.componentId === ids.flour)!;
    expect(Number(flourLine.ratioPercent)).toBe(60);

    // The old version is retired; bomOf now resolves the new one.
    const nowActive = await bomOf(ids.sponge);
    expect(nowActive.id).toBe(created.id);
    const old = await prisma.mfgBom.findUniqueOrThrow({ where: { id: before.id } });
    expect(old.active).toBe(false);
  });

  // ── increment 8: maintenance + OEE ──
  it('maintenance: plan → complete records downtime; a second complete is rejected', async () => {
    const wc = await prisma.mfgWorkCenter.findFirstOrThrow();
    const m = await mfg.createMaintenance({
      workCenterId: wc.id,
      scheduledDate: new Date().toISOString(),
      note: 'Vệ sinh lò',
    });
    expect(m.state).toBe('PLANNED');

    const done = await mfg.completeMaintenance(m.id, { downtimeMin: 30 });
    expect(done.state).toBe('DONE');
    expect(done.downtimeMin).toBe(30);
    expect(done.doneDate).not.toBeNull();

    await expect(mfg.completeMaintenance(m.id, { downtimeMin: 5 })).rejects.toThrow(/hoàn tất/);
  });

  it('OEE report aggregates per work centre; downtime lowers availability', async () => {
    const bom = await bomOf(ids.cake); // cake ops carry no QC → doneWO not gated
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 100 });
    await mfg.confirmMO(mo.id);
    const wo = await prisma.mfgWorkOrder.findFirstOrThrow({
      where: { moId: mo.id },
      orderBy: { sequence: 'asc' },
    });
    // Run it for ~20 real minutes, then finish (banks durationReal).
    await prisma.mfgWorkOrder.update({
      where: { id: wo.id },
      data: { state: 'PROGRESS', dateStart: new Date(Date.now() - 20 * 60000) },
    });
    const doneWo = await mfg.doneWO(wo.id);
    expect(doneWo.durationReal).toBeGreaterThanOrEqual(19);

    const wcId = wo.workCenterId;
    const m = await mfg.createMaintenance({
      workCenterId: wcId,
      scheduledDate: new Date().toISOString(),
    });
    await mfg.completeMaintenance(m.id, { downtimeMin: 60 });

    const oee = await mfg.oeeReport();
    const row = oee.rows.find((r) => r.workCenterId === wcId);
    expect(row).toBeDefined();
    expect(row!.runtimeMin).toBeGreaterThanOrEqual(19);
    expect(row!.downtimeMin).toBeGreaterThanOrEqual(60);
    // availability = runtime / (runtime + downtime): strictly between 0 and 1 here.
    expect(row!.availability).toBeGreaterThan(0);
    expect(row!.availability).toBeLessThan(1);
    expect(row!.quality).toBeLessThanOrEqual(1);
    expect(row!.oee).toBeGreaterThanOrEqual(0);
    expect(row!.oee).toBeLessThanOrEqual(1);
  });

  // ── increment 9: hard reservations (per-MO allocation ledger) ──
  it("cancelling one MO releases only its own hold, never another MO's", async () => {
    const stockLoc = await prisma.mfgLocation.findUniqueOrThrow({ where: { code: 'STOCK' } });
    await prisma.mfgReservation.deleteMany();
    await prisma.mfgStockQuant.deleteMany({
      where: { productId: ids.flour, locationId: stockLoc.id },
    });
    const bom = await bomOf(ids.sponge);
    const moA = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    const moB = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(moA.id);
    await mfg.confirmMO(moB.id);
    // The active BoM sets the flour need; size two lots to exactly that so A fills
    // one quant and B fills the other (distinct quants — where an ownership-blind
    // release would free the wrong MO's stock).
    const flourNeed = Number(
      (
        await prisma.mfgOrderComponent.findFirstOrThrow({
          where: { moId: moA.id, productId: ids.flour },
        })
      ).qtyToConsume,
    );
    const lot1 = await prisma.mfgLot.create({
      data: { productId: ids.flour, name: 'HR-L1', mfgDate: new Date() },
    });
    const lot2 = await prisma.mfgLot.create({
      data: { productId: ids.flour, name: 'HR-L2', mfgDate: new Date() },
    });
    await prisma.mfgStockQuant.create({
      data: {
        productId: ids.flour,
        lotId: lot1.id,
        locationId: stockLoc.id,
        quantity: flourNeed,
        reservedQty: 0,
      },
    });
    await prisma.mfgStockQuant.create({
      data: {
        productId: ids.flour,
        lotId: lot2.id,
        locationId: stockLoc.id,
        quantity: flourNeed,
        reservedQty: 0,
      },
    });

    await mfg.reserve(moA.id); // fills one quant
    await mfg.reserve(moB.id); // fills the other

    const bRes = await prisma.mfgReservation.findFirstOrThrow({
      where: { moId: moB.id, productId: ids.flour },
    });
    const totalBefore = (
      await prisma.mfgStockQuant.aggregate({
        where: { productId: ids.flour, locationId: stockLoc.id },
        _sum: { reservedQty: true },
      })
    )._sum.reservedQty;
    expect(Number(totalBefore)).toBe(flourNeed * 2); // both holds live

    await mfg.cancelMO(moA.id);

    // A's ledger gone; B's hold — on its OWN quant — untouched.
    expect(await prisma.mfgReservation.count({ where: { moId: moA.id } })).toBe(0);
    const bQuant = await prisma.mfgStockQuant.findUniqueOrThrow({ where: { id: bRes.quantId } });
    expect(Number(bQuant.reservedQty)).toBe(flourNeed);
    const totalAfter = (
      await prisma.mfgStockQuant.aggregate({
        where: { productId: ids.flour, locationId: stockLoc.id },
        _sum: { reservedQty: true },
      })
    )._sum.reservedQty;
    expect(Number(totalAfter)).toBe(flourNeed); // exactly B's hold remains
    const bComp = await prisma.mfgOrderComponent.findFirstOrThrow({
      where: { moId: moB.id, productId: ids.flour },
    });
    expect(Number(bComp.reservedQty)).toBe(flourNeed);
  });

  it('producing an MO releases its reservation and consumes real stock once', async () => {
    const stockLoc = await prisma.mfgLocation.findUniqueOrThrow({ where: { code: 'STOCK' } });
    await prisma.mfgReservation.deleteMany();
    const bom = await bomOf(ids.sponge);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(mo.id);
    const flourNeed = Number(
      (
        await prisma.mfgOrderComponent.findFirstOrThrow({
          where: { moId: mo.id, productId: ids.flour },
        })
      ).qtyToConsume,
    );
    // Fresh 5000 of every sponge component on one clean quant each.
    for (const pid of [ids.flour, ids.sugar, ids.egg]) {
      await prisma.mfgStockQuant.deleteMany({ where: { productId: pid, locationId: stockLoc.id } });
      await prisma.mfgStockQuant.create({
        data: {
          productId: pid,
          lotId: null,
          locationId: stockLoc.id,
          quantity: 5000,
          reservedQty: 0,
        },
      });
    }
    await mfg.reserve(mo.id);
    expect(await prisma.mfgReservation.count({ where: { moId: mo.id } })).toBeGreaterThan(0);

    await mfg.produce(mo.id);

    // Ledger cleared, and flour on hand dropped by exactly its need (consumed once).
    expect(await prisma.mfgReservation.count({ where: { moId: mo.id } })).toBe(0);
    const flour = await prisma.mfgStockQuant.aggregate({
      where: { productId: ids.flour, locationId: stockLoc.id },
      _sum: { quantity: true, reservedQty: true },
    });
    expect(Number(flour._sum.quantity)).toBe(5000 - flourNeed);
    expect(Number(flour._sum.reservedQty)).toBe(0); // hold released, not stranded
  });

  // ── increment 9 review fixes ──
  it("produce consumes only free stock — it never eats another MO's reservation", async () => {
    const stockLoc = await prisma.mfgLocation.findUniqueOrThrow({ where: { code: 'STOCK' } });
    await prisma.mfgReservation.deleteMany();
    const bom = await bomOf(ids.sponge);
    const moA = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(moA.id);
    const flourNeed = Number(
      (
        await prisma.mfgOrderComponent.findFirstOrThrow({
          where: { moId: moA.id, productId: ids.flour },
        })
      ).qtyToConsume,
    );
    // Exactly enough flour for ONE MO on a lot-quant, reserved entirely to A.
    await prisma.mfgStockQuant.deleteMany({
      where: { productId: ids.flour, locationId: stockLoc.id },
    });
    const lot = await prisma.mfgLot.create({
      data: { productId: ids.flour, name: 'HR-P1', mfgDate: new Date() },
    });
    await prisma.mfgStockQuant.create({
      data: {
        productId: ids.flour,
        lotId: lot.id,
        locationId: stockLoc.id,
        quantity: flourNeed,
        reservedQty: 0,
      },
    });
    await mfg.reserve(moA.id);

    // A second sponge MO produces — it must NOT touch A's reserved flour.
    const moB = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(moB.id);
    await mfg.produce(moB.id);

    // B saw 0 free on A's lot-quant → its shortfall backflushed to a separate
    // (negative) quant; A's reserved lot-quant is physically untouched.
    const aQuant = await prisma.mfgStockQuant.findFirstOrThrow({
      where: { productId: ids.flour, lotId: lot.id, locationId: stockLoc.id },
    });
    expect(Number(aQuant.quantity)).toBe(flourNeed);
    expect(Number(aQuant.reservedQty)).toBe(flourNeed);
    expect(await prisma.mfgReservation.count({ where: { moId: moA.id } })).toBeGreaterThan(0);
  });

  it('checkAvailability stays AVAILABLE for the MO that just reserved', async () => {
    const stockLoc = await prisma.mfgLocation.findUniqueOrThrow({ where: { code: 'STOCK' } });
    await prisma.mfgReservation.deleteMany();
    const bom = await bomOf(ids.sponge);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(mo.id);
    // Exactly each component's need on hand — so after reserving, free stock is 0.
    const detail = await mfg.getMO(mo.id);
    for (const c of detail!.components) {
      await prisma.mfgStockQuant.deleteMany({
        where: { productId: c.productId, locationId: stockLoc.id },
      });
      await prisma.mfgStockQuant.create({
        data: {
          productId: c.productId,
          lotId: null,
          locationId: stockLoc.id,
          quantity: Number(c.qtyToConsume),
          reservedQty: 0,
        },
      });
    }
    const reserved = await mfg.reserve(mo.id);
    // Its own hold counts toward availability — it must not flip to Not-available.
    for (const c of reserved.components) expect(c.status).toBe('AVAILABLE');
  });

  it('direct produce banks standard time on its work orders (OEE runtime nonzero)', async () => {
    await prisma.mfgReservation.deleteMany();
    const bom = await bomOf(ids.sponge);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(mo.id);
    await mfg.produce(mo.id); // WOs closed via produce, never run on the shop floor

    const wos = await prisma.mfgWorkOrder.findMany({ where: { moId: mo.id } });
    expect(wos.length).toBeGreaterThan(0);
    for (const wo of wos) {
      expect(wo.state).toBe('DONE');
      expect(wo.durationReal).toBe(wo.durationExpected); // standard time banked, not 0
    }
  });
});

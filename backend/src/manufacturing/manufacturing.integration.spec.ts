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
    await prisma.mfgPurchaseOrderLine.deleteMany();
    await prisma.mfgPurchaseOrder.deleteMany();
    await prisma.mfgSupplier.deleteMany();
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

  const completeWorkOrders = async (moId: string) => {
    const workOrders = await prisma.mfgWorkOrder.findMany({
      where: { moId },
      orderBy: { sequence: 'asc' },
      include: {
        bomOperation: { include: { qualityPoints: { where: { active: true } } } },
      },
    });
    for (const workOrder of workOrders) {
      await mfg.startWO(workOrder.id);
      for (const point of workOrder.bomOperation.qualityPoints) {
        await mfg.recordCheck({
          qualityPointId: point.id,
          workOrderId: workOrder.id,
          measuredValue:
            point.testType === 'MEASURE' ? Number(point.normMin ?? point.normMax ?? 0) : undefined,
          passFail: point.testType === 'PASS_FAIL' ? 'PASS' : undefined,
        });
      }
      await mfg.doneWO(workOrder.id);
    }
  };

  const prepareForProduce = async (moId: string) => {
    await mfg.reserve(moId);
    await completeWorkOrders(moId);
  };

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
    await prepareForProduce(mo.id);
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
    await prepareForProduce(moId);
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

  it('enforces operation sequence, start-before-done, and QC ownership', async () => {
    const bom = await bomOf(ids.sponge);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 200 });
    await mfg.confirmMO(mo.id);
    const workOrders = await prisma.mfgWorkOrder.findMany({
      where: { moId: mo.id },
      orderBy: { sequence: 'asc' },
      include: { bomOperation: { include: { qualityPoints: true } } },
    });
    expect(workOrders.length).toBeGreaterThan(1);
    expect(workOrders[0].state).toBe('READY');
    expect(workOrders[1].state).toBe('PENDING');
    await expect(mfg.startWO(workOrders[1].id)).rejects.toThrow(/sẵn sàng/i);
    await expect(mfg.doneWO(workOrders[0].id)).rejects.toThrow(/Bắt đầu/i);

    const point = workOrders[0].bomOperation.qualityPoints[0];
    expect(point).toBeDefined();
    await expect(
      mfg.recordCheck({
        qualityPointId: point.id,
        workOrderId: workOrders[1].id,
        measuredValue: Number(point.normMin ?? 0),
        passFail: point.testType === 'PASS_FAIL' ? 'PASS' : undefined,
      }),
    ).rejects.toThrow(/không thuộc/i);

    await completeWorkOrders(mo.id);
    const finished = await prisma.mfgWorkOrder.findMany({ where: { moId: mo.id } });
    expect(finished.every((wo) => wo.state === 'DONE')).toBe(true);
  });

  it('creates QC points together with a versioned BoM operation', async () => {
    const category = await prisma.mfgCategory.findFirstOrThrow();
    const wc = await prisma.mfgWorkCenter.findFirstOrThrow();
    const product = await mfg.createProduct({
      code: `QC-DEMO-${Date.now()}`,
      nameVi: 'Bánh demo QC',
      categoryId: category.id,
      uomId: gUom,
      type: 'FINISHED',
      tracking: 'LOT',
    });
    const bom = await mfg.createBom({
      productId: product.id,
      outputQty: 1,
      uomId: gUom,
      lines: [{ componentId: ids.flour, qty: 1, uomId: gUom }],
      operations: [
        {
          nameVi: 'Nướng thử',
          workCenterId: wc.id,
          durationMinutes: 10,
          qualityPoints: [
            {
              titleVi: 'Nhiệt độ tâm bánh',
              testType: 'MEASURE',
              normMin: 90,
              normMax: 96,
              unit: '°C',
            },
            { titleVi: 'Bề mặt đạt chuẩn', testType: 'PASS_FAIL' },
          ],
        },
      ],
    });
    const operation = await prisma.mfgBomOperation.findFirstOrThrow({
      where: { bomId: bom.id },
      include: { qualityPoints: true },
    });
    expect(operation.qualityPoints).toHaveLength(2);
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
    await mfg.reserve(mo.id);

    // Even a corrupted/stale client that marks WOs done directly cannot bypass QC.
    await prisma.mfgWorkOrder.updateMany({
      where: { moId: mo.id },
      data: { state: 'DONE', dateFinished: new Date() },
    });
    await expect(mfg.produce(mo.id)).rejects.toThrow(/kiểm tra|đạt/i);

    // Restore the first operation, record every check, and close it correctly.
    await prisma.mfgWorkOrder.update({
      where: { id: wo.id },
      data: { state: 'PROGRESS', dateStart: new Date() },
    });
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
    await mfg.doneWO(wo.id);
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
    await prepareForProduce(mo.id);

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

  it('two concurrent MO confirms create one ordered set of work orders', async () => {
    const bom = await bomOf(ids.cake);
    const operationCount = await prisma.mfgBomOperation.count({ where: { bomId: bom.id } });
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 100 });

    const results = await Promise.allSettled([mfg.confirmMO(mo.id), mfg.confirmMO(mo.id)]);
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(results.filter((r) => r.status === 'rejected')).toHaveLength(1);

    const workOrders = await prisma.mfgWorkOrder.findMany({
      where: { moId: mo.id },
      orderBy: { sequence: 'asc' },
    });
    expect(workOrders).toHaveLength(operationCount);
    expect(workOrders[0]?.state).toBe('READY');
    expect(workOrders.slice(1).every((wo) => wo.state === 'PENDING')).toBe(true);
  });

  it('produce vs cancel race: exactly one wins and the state stays consistent', async () => {
    // Cake ops carry no QC points; stock its components so produce can run.
    await mfg.receive({ productId: ids.sponge, qty: 5000, uomId: gUom, unitCost: 180.25 });
    await mfg.receive({ productId: ids.cream, qty: 5000, uomId: gUom, unitCost: 120 });
    await mfg.receive({ productId: ids.berry, qty: 5000, uomId: gUom, unitCost: 200 });
    const bom = await bomOf(ids.cake);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(mo.id);
    await prepareForProduce(mo.id);
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
    await completeWorkOrders(mo.id);

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

    // A second sponge MO may reserve other ingredients, but cannot close while
    // A owns the only flour allocation.
    const moB = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(moB.id);
    await mfg.reserve(moB.id);
    await completeWorkOrders(moB.id);
    await expect(mfg.produce(moB.id)).rejects.toThrow(/giữ đủ/i);

    // No backflush: A's reserved lot-quant remains physically untouched.
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

  it('produce cannot bypass work-order execution', async () => {
    await prisma.mfgReservation.deleteMany();
    const bom = await bomOf(ids.sponge);
    const mo = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(mo.id);
    const detail = await mfg.getMO(mo.id);
    const stockLoc = await prisma.mfgLocation.findUniqueOrThrow({ where: { code: 'STOCK' } });
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
    await mfg.reserve(mo.id);
    await expect(mfg.produce(mo.id)).rejects.toThrow(/công đoạn/i);

    const wos = await prisma.mfgWorkOrder.findMany({ where: { moId: mo.id } });
    expect(wos.length).toBeGreaterThan(0);
    for (const wo of wos) {
      expect(wo.state).not.toBe('DONE');
    }
  });

  it('two MOs producing the same raw never overdraw its free stock (concurrent)', async () => {
    const stockLoc = await prisma.mfgLocation.findUniqueOrThrow({ where: { code: 'STOCK' } });
    await prisma.mfgReservation.deleteMany();
    const bom = await bomOf(ids.sponge);

    const moA = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(moA.id);
    const moB = await mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 });
    await mfg.confirmMO(moB.id);

    const detail = await mfg.getMO(moA.id);
    const flourNeed = Number(
      detail!.components.find((c) => c.productId === ids.flour)!.qtyToConsume,
    );
    // Ample free stock for every OTHER component so only flour is contended.
    for (const c of detail!.components) {
      await prisma.mfgStockQuant.deleteMany({
        where: { productId: c.productId, locationId: stockLoc.id },
      });
      if (c.productId === ids.flour) continue;
      await prisma.mfgStockQuant.create({
        data: {
          productId: c.productId,
          lotId: null,
          locationId: stockLoc.id,
          quantity: Number(c.qtyToConsume) * 2,
          reservedQty: 0,
        },
      });
    }
    // Flour: free for exactly ONE MO. Concurrent reserve must allocate it once.
    const lot = await prisma.mfgLot.create({
      data: { productId: ids.flour, name: 'HR-P1-RACE', mfgDate: new Date() },
    });
    const flourQuant = await prisma.mfgStockQuant.create({
      data: {
        productId: ids.flour,
        lotId: lot.id,
        locationId: stockLoc.id,
        quantity: flourNeed,
        reservedQty: 0,
      },
    });

    await Promise.all([mfg.reserve(moA.id), mfg.reserve(moB.id)]);
    await Promise.all([completeWorkOrders(moA.id), completeWorkOrders(moB.id)]);

    // Exactly one order owns a complete material set and may close. The loser is
    // blocked instead of creating negative stock.
    const res = await Promise.allSettled([mfg.produce(moA.id), mfg.produce(moB.id)]);
    expect(res.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(res.filter((r) => r.status === 'rejected')).toHaveLength(1);

    const after = await prisma.mfgStockQuant.findUniqueOrThrow({ where: { id: flourQuant.id } });
    expect(Number(after.quantity)).toBe(0); // drained exactly once, never overdrawn
    // Exactly one real consume move drew from the lot; there is no backflush.
    const lotConsumes = await prisma.mfgStockMove.count({
      where: { productId: ids.flour, lotId: lot.id, refType: 'MO' },
    });
    expect(lotConsumes).toBe(1);
  });

  it('product CRUD: create, duplicate-code 409, edit, archive hides from pickers', async () => {
    const cat = await prisma.mfgCategory.findFirstOrThrow();
    const gram = await prisma.mfgUom.findFirstOrThrow({ where: { code: 'g' } });

    const created = await mfg.createProduct({
      code: 'TEST-PM-BUTTER',
      nameVi: 'Bơ lạt test',
      categoryId: cat.id,
      uomId: gram.id,
      type: 'RAW',
      tracking: 'LOT',
      useExpiration: true,
      expirationDays: 30,
      standardCost: 250,
    });
    expect(created.code).toBe('TEST-PM-BUTTER');
    expect(created.tracking).toBe('LOT');
    expect(Number(created.standardCost)).toBe(250);

    // Duplicate code refused.
    await expect(
      mfg.createProduct({
        code: 'TEST-PM-BUTTER',
        nameVi: 'Trùng mã',
        categoryId: cat.id,
        uomId: gram.id,
        type: 'RAW',
      }),
    ).rejects.toMatchObject({ status: 409 });

    // Edit fields.
    const updated = await mfg.updateProduct(created.id, {
      nameVi: 'Bơ lạt Anchor',
      expirationDays: 45,
    });
    expect(updated.nameVi).toBe('Bơ lạt Anchor');
    expect(updated.expirationDays).toBe(45);

    // Archive: gone from the default picker list, still on the management list.
    await mfg.updateProduct(created.id, { active: false });
    const pickers = await mfg.listProducts('RAW');
    expect(pickers.some((p) => p.id === created.id)).toBe(false);
    const admin = await mfg.listProducts(undefined, true);
    expect(admin.some((p) => p.id === created.id)).toBe(true);

    // Reactivate + master-data reads used by the form.
    await mfg.updateProduct(created.id, { active: true });
    expect((await mfg.listCategories()).length).toBeGreaterThan(0);
    expect((await mfg.listUoms()).some((u) => u.code === 'g')).toBe(true);
  });

  it('product base UoM locks once stock has moved', async () => {
    const cat = await prisma.mfgCategory.findFirstOrThrow();
    const gram = await prisma.mfgUom.findFirstOrThrow({ where: { code: 'g' } });
    const unit = await prisma.mfgUom.findFirstOrThrow({
      where: { category: 'unit' },
    });

    const p = await mfg.createProduct({
      code: 'TEST-PM-UOMLOCK',
      nameVi: 'Test khoá đơn vị',
      categoryId: cat.id,
      uomId: gram.id,
      type: 'RAW',
    });
    // Before any movement the UoM may still change.
    await mfg.updateProduct(p.id, { uomId: unit.id });
    await mfg.updateProduct(p.id, { uomId: gram.id });

    await mfg.receive({ productId: p.id, qty: 100, unitCost: 10 });
    await expect(mfg.updateProduct(p.id, { uomId: unit.id })).rejects.toMatchObject({
      status: 409,
    });
  });

  it('product base UoM locks on BoM references too, not just stock moves', async () => {
    const cat = await prisma.mfgCategory.findFirstOrThrow();
    const gram = await prisma.mfgUom.findFirstOrThrow({ where: { code: 'g' } });
    const unit = await prisma.mfgUom.findFirstOrThrow({ where: { category: 'unit' } });

    // Fresh output product + fresh line component: ZERO stock moves, only a BoM
    // wires them. Both must refuse a base-UoM change (produce() converts the
    // output with the product's CURRENT uom; line qty is denominated in the
    // component's unit) — this was the g→kg AVCO-corruption hole.
    const out = await mfg.createProduct({
      code: 'TEST-PM-UOMREF-OUT',
      nameVi: 'Ref output',
      categoryId: cat.id,
      uomId: gram.id,
      type: 'FINISHED',
    });
    const comp = await mfg.createProduct({
      code: 'TEST-PM-UOMREF-COMP',
      nameVi: 'Ref component',
      categoryId: cat.id,
      uomId: gram.id,
      type: 'RAW',
    });
    await prisma.mfgBom.create({
      data: {
        productId: out.id,
        outputQty: 1000,
        uomId: gram.id,
        version: 1,
        active: true,
        lines: { create: [{ componentId: comp.id, qty: 500, uomId: gram.id }] },
      },
    });

    await expect(mfg.updateProduct(out.id, { uomId: unit.id })).rejects.toMatchObject({
      status: 409,
    });
    await expect(mfg.updateProduct(comp.id, { uomId: unit.id })).rejects.toMatchObject({
      status: 409,
    });
  });

  it('product expiry rules: LOT required for HSD, days >= 1 when enabled', async () => {
    const cat = await prisma.mfgCategory.findFirstOrThrow();
    const gram = await prisma.mfgUom.findFirstOrThrow({ where: { code: 'g' } });

    // useExpiration without lot tracking → 400.
    await expect(
      mfg.createProduct({
        code: 'TEST-PM-EXP1',
        nameVi: 'HSD không lô',
        categoryId: cat.id,
        uomId: gram.id,
        type: 'RAW',
        useExpiration: true,
        expirationDays: 5,
      }),
    ).rejects.toMatchObject({ status: 400 });

    // useExpiration with 0 days → 400 (every lot would silently get no expiry).
    await expect(
      mfg.createProduct({
        code: 'TEST-PM-EXP2',
        nameVi: 'HSD 0 ngày',
        categoryId: cat.id,
        uomId: gram.id,
        type: 'RAW',
        tracking: 'LOT',
        useExpiration: true,
        expirationDays: 0,
      }),
    ).rejects.toMatchObject({ status: 400 });

    // Partial update can't sneak an incoherent merge past the rule either.
    const ok = await mfg.createProduct({
      code: 'TEST-PM-EXP3',
      nameVi: 'HSD hợp lệ',
      categoryId: cat.id,
      uomId: gram.id,
      type: 'RAW',
      tracking: 'LOT',
      useExpiration: true,
      expirationDays: 7,
    });
    await expect(mfg.updateProduct(ok.id, { expirationDays: 0 })).rejects.toMatchObject({
      status: 400,
    });
    await expect(mfg.updateProduct(ok.id, { tracking: 'NONE' })).rejects.toMatchObject({
      status: 400,
    });

    // Empty/whitespace code refused (would break lot names + the dup check).
    await expect(
      mfg.createProduct({
        code: '   ',
        nameVi: 'Mã rỗng',
        categoryId: cat.id,
        uomId: gram.id,
        type: 'RAW',
      }),
    ).rejects.toMatchObject({ status: 400 });
    await expect(mfg.updateProduct(ok.id, { code: '' })).rejects.toMatchObject({ status: 400 });
  });

  it('archiving a product hides its BoM and blocks receive/createMO', async () => {
    const cat = await prisma.mfgCategory.findFirstOrThrow();
    const gram = await prisma.mfgUom.findFirstOrThrow({ where: { code: 'g' } });
    const p = await mfg.createProduct({
      code: 'TEST-PM-ARCH',
      nameVi: 'Bánh ngừng bán',
      categoryId: cat.id,
      uomId: gram.id,
      type: 'FINISHED',
    });
    const bom = await prisma.mfgBom.create({
      data: {
        productId: p.id,
        outputQty: 1000,
        uomId: gram.id,
        version: 1,
        active: true,
        lines: { create: [{ componentId: ids.flour, qty: 500, uomId: gram.id }] },
      },
    });

    await mfg.updateProduct(p.id, { active: false });

    // BoM gone from the batch picker.
    const boms = await mfg.listBoms();
    expect(boms.some((b) => b.id === bom.id)).toBe(false);
    // createMO + receive refuse the archived product.
    await expect(mfg.createMO({ bomId: bom.id, qtyToProduce: 1000 })).rejects.toMatchObject({
      status: 400,
    });
    await expect(mfg.receive({ productId: p.id, qty: 100, unitCost: 10 })).rejects.toMatchObject({
      status: 400,
    });

    // Reactivate → picker shows it again.
    await mfg.updateProduct(p.id, { active: true });
    expect((await mfg.listBoms()).some((b) => b.id === bom.id)).toBe(true);
  });

  it('expiringLots only reports lots with stock still on hand', async () => {
    const stockLoc = await prisma.mfgLocation.findUniqueOrThrow({ where: { code: 'STOCK' } });
    const soon = new Date(Date.now() + 24 * 3600 * 1000);
    const consumed = await prisma.mfgLot.create({
      data: { productId: ids.flour, name: 'EXP-CONSUMED', mfgDate: new Date(), expiryDate: soon },
    });
    const live = await prisma.mfgLot.create({
      data: { productId: ids.flour, name: 'EXP-LIVE', mfgDate: new Date(), expiryDate: soon },
    });
    // Consumed lot: quant exists but is empty. Live lot: stock on hand.
    await prisma.mfgStockQuant.create({
      data: { productId: ids.flour, lotId: consumed.id, locationId: stockLoc.id, quantity: 0 },
    });
    await prisma.mfgStockQuant.create({
      data: { productId: ids.flour, lotId: live.id, locationId: stockLoc.id, quantity: 250 },
    });

    const rows = await mfg.expiringLots(new Date(Date.now() + 3 * 86400000).toISOString());
    const names = rows.map((r) => r.name);
    expect(names).toContain('EXP-LIVE');
    expect(names).not.toContain('EXP-CONSUMED');
  });

  it('createBom enforces output/component types (no RAW output, no FINISHED input)', async () => {
    const gram = await prisma.mfgUom.findFirstOrThrow({ where: { code: 'g' } });

    // RAW as recipe output → 400.
    await expect(
      mfg.createBom({
        productId: ids.flour,
        outputQty: 1000,
        uomId: gram.id,
        lines: [{ componentId: ids.sugar, qty: 500, uomId: gram.id }],
      }),
    ).rejects.toMatchObject({ status: 400 });

    // FINISHED good as ingredient → 400.
    await expect(
      mfg.createBom({
        productId: ids.sponge,
        outputQty: 1000,
        uomId: gram.id,
        lines: [{ componentId: ids.cake, qty: 100, uomId: gram.id }],
      }),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('archived ingredient hides the recipe and blocks createMO', async () => {
    const bom = await bomOf(ids.sponge);

    await mfg.updateProduct(ids.flour, { active: false });
    try {
      // Recipe with an archived line component leaves the picker…
      expect((await mfg.listBoms()).some((b) => b.id === bom.id)).toBe(false);
      // …and a stale client still can't order it.
      await expect(mfg.createMO({ bomId: bom.id, qtyToProduce: 500 })).rejects.toMatchObject({
        status: 400,
      });
      // New recipes can't reference it either.
      const gram = await prisma.mfgUom.findFirstOrThrow({ where: { code: 'g' } });
      await expect(
        mfg.createBom({
          productId: ids.sponge,
          outputQty: 1000,
          uomId: gram.id,
          lines: [{ componentId: ids.flour, qty: 500, uomId: gram.id }],
        }),
      ).rejects.toMatchObject({ status: 400 });
    } finally {
      await mfg.updateProduct(ids.flour, { active: true });
    }
    expect((await mfg.listBoms()).some((b) => b.id === bom.id)).toBe(true);
  });

  it('legacy invalid BoMs (pre-type-rules) are hidden from the picker and refused by createMO', async () => {
    const gram = await prisma.mfgUom.findFirstOrThrow({ where: { code: 'g' } });

    // Authored straight in the DB, as the old UI could: RAW output.
    const rawOut = await prisma.mfgBom.create({
      data: {
        productId: ids.flour, // RAW
        outputQty: 1000,
        uomId: gram.id,
        version: 99,
        active: true,
        lines: { create: [{ componentId: ids.sugar, qty: 500, uomId: gram.id }] },
      },
    });
    // And a FINISHED good as an ingredient.
    const finishedIn = await prisma.mfgBom.create({
      data: {
        productId: ids.sponge, // SEMI — valid output
        outputQty: 1000,
        uomId: gram.id,
        version: 99,
        active: true,
        lines: { create: [{ componentId: ids.cake, qty: 100, uomId: gram.id }] },
      },
    });

    try {
      const visible = (await mfg.listBoms()).map((b) => b.id);
      expect(visible).not.toContain(rawOut.id);
      expect(visible).not.toContain(finishedIn.id);

      await expect(mfg.createMO({ bomId: rawOut.id, qtyToProduce: 100 })).rejects.toMatchObject({
        status: 400,
      });
      await expect(mfg.createMO({ bomId: finishedIn.id, qtyToProduce: 100 })).rejects.toMatchObject(
        { status: 400 },
      );
    } finally {
      await prisma.mfgBom.delete({ where: { id: rawOut.id } });
      await prisma.mfgBom.delete({ where: { id: finishedIn.id } });
    }
  });

  it('createMO refuses a retired (inactive) BoM version', async () => {
    const gram = await prisma.mfgUom.findFirstOrThrow({ where: { code: 'g' } });
    // A retired version, straight in the DB (as createBom leaves behind).
    const retired = await prisma.mfgBom.create({
      data: {
        productId: ids.sponge,
        outputQty: 1000,
        uomId: gram.id,
        version: 98,
        active: false,
        lines: { create: [{ componentId: ids.flour, qty: 500, uomId: gram.id }] },
      },
    });
    try {
      await expect(mfg.createMO({ bomId: retired.id, qtyToProduce: 100 })).rejects.toMatchObject({
        status: 400,
      });
    } finally {
      await prisma.mfgBom.delete({ where: { id: retired.id } });
    }
  });

  it('two same-code creates racing: loser gets 409, never a 500', async () => {
    const cat = await prisma.mfgCategory.findFirstOrThrow();
    const gram = await prisma.mfgUom.findFirstOrThrow({ where: { code: 'g' } });
    const mk = () =>
      mfg.createProduct({
        code: 'TEST-PM-RACE',
        nameVi: 'Đua trùng mã',
        categoryId: cat.id,
        uomId: gram.id,
        type: 'RAW',
      });
    const results = await Promise.allSettled([mk(), mk()]);
    const ok = results.filter((r) => r.status === 'fulfilled').length;
    const rejected = results.filter((r) => r.status === 'rejected') as PromiseRejectedResult[];
    expect(ok).toBe(1);
    expect(rejected).toHaveLength(1);
    // The DB-constraint loser must surface as the same 409 as the pre-check.
    expect((rejected[0].reason as { status?: number }).status).toBe(409);
  });

  // ── purchasing (P2: supplier → PO → receipt → history) ──
  it('runs a PO from draft to received, driving qtyReceived, state and history', async () => {
    const supplier = await mfg.createSupplier({ name: 'Bột Mì Phương Nam' });

    // Draft with 2 lines, in the products' base UoM (g).
    const po = await mfg.createPurchaseOrder({
      supplierId: supplier.id,
      note: 'Đợt bột tháng 7',
      lines: [
        { productId: ids.flour, qty: 1000, unitPrice: 28 },
        { productId: ids.sugar, qty: 500, unitPrice: 24 },
      ],
    });
    expect(po.state).toBe('DRAFT');
    expect(po.code).toMatch(/^PO-\d{5}$/);

    // Receiving against a draft PO must refuse.
    const flourLine = po.lines.find((l) => l.productId === ids.flour)!;
    await expect(
      mfg.receive({
        productId: ids.flour,
        qty: 1000,
        uomId: gUom,
        unitCost: 28,
        poLineId: flourLine.id,
      }),
    ).rejects.toMatchObject({ status: 400 });

    await mfg.confirmPurchaseOrder(po.id);

    // Receive the flour line in full → PO goes PARTIAL, line filled.
    await mfg.receive({
      productId: ids.flour,
      qty: 1000,
      uomId: gUom,
      unitCost: 28,
      poLineId: flourLine.id,
    });
    let fresh = await mfg.getPurchaseOrder(po.id);
    expect(fresh.state).toBe('PARTIAL');
    expect(Number(fresh.lines.find((l) => l.productId === ids.flour)!.qtyReceived)).toBe(1000);

    // Wrong product against the sugar line must refuse.
    const sugarLine = fresh.lines.find((l) => l.productId === ids.sugar)!;
    await expect(
      mfg.receive({
        productId: ids.flour,
        qty: 100,
        uomId: gUom,
        unitCost: 24,
        poLineId: sugarLine.id,
      }),
    ).rejects.toMatchObject({ status: 400 });

    // Receive sugar in two parts → PARTIAL until complete, then RECEIVED.
    await mfg.receive({
      productId: ids.sugar,
      qty: 200,
      uomId: gUom,
      unitCost: 24,
      poLineId: sugarLine.id,
    });
    fresh = await mfg.getPurchaseOrder(po.id);
    expect(fresh.state).toBe('PARTIAL');
    await mfg.receive({
      productId: ids.sugar,
      qty: 300,
      uomId: gUom,
      unitCost: 24,
      poLineId: sugarLine.id,
    });
    fresh = await mfg.getPurchaseOrder(po.id);
    expect(fresh.state).toBe('RECEIVED');

    // History carries the supplier + PO code on linked receipts, null on legacy.
    const history = await mfg.purchaseHistory(ids.flour);
    expect(history[0].supplierName).toBe('Bột Mì Phương Nam');
    expect(history[0].poCode).toBe(po.code);
    expect(history[0].unitCost).toBe(28);
    expect(history.some((h) => h.supplierName === null)).toBe(true); // earlier ad-hoc receives

    // Draft-only edit guard: the received PO can no longer be edited.
    await expect(mfg.updatePurchaseOrder(po.id, { note: 'sửa muộn' })).rejects.toMatchObject({
      status: 400,
    });
  });

  // ── PO concurrency (review round: locks + sequence) ──
  it('blocks over-receiving a PO line and books nothing', async () => {
    const supplier = await mfg.createSupplier({ name: 'NCC Nhận Vượt' });
    const po = await mfg.createPurchaseOrder({
      supplierId: supplier.id,
      lines: [{ productId: ids.egg, qty: 100, unitPrice: 35 }],
    });
    await mfg.confirmPurchaseOrder(po.id);
    const before = await onHand(ids.egg);
    const avgBefore = Number(
      (await prisma.mfgProduct.findUniqueOrThrow({ where: { id: ids.egg } })).avgCost,
    );
    await expect(
      mfg.receive({
        productId: ids.egg,
        qty: 150,
        uomId: gUom,
        unitCost: 40,
        poLineId: po.lines[0].id,
      }),
    ).rejects.toMatchObject({ status: 400 });
    // Rejected receipt must leave stock, AVCO, line and state untouched.
    expect(await onHand(ids.egg)).toBe(before);
    const avgAfter = Number(
      (await prisma.mfgProduct.findUniqueOrThrow({ where: { id: ids.egg } })).avgCost,
    );
    expect(avgAfter).toBe(avgBefore);
    const fresh = await mfg.getPurchaseOrder(po.id);
    expect(fresh.state).toBe('CONFIRMED');
    expect(Number(fresh.lines[0].qtyReceived)).toBe(0);
  });

  it('two lines received concurrently end RECEIVED with correct qtyReceived (no stuck PARTIAL)', async () => {
    const supplier = await mfg.createSupplier({ name: 'NCC Song Song' });
    const po = await mfg.createPurchaseOrder({
      supplierId: supplier.id,
      lines: [
        { productId: ids.flour, qty: 500, unitPrice: 30 },
        { productId: ids.sugar, qty: 300, unitPrice: 25 },
      ],
    });
    await mfg.confirmPurchaseOrder(po.id);
    const flourLine = po.lines.find((l) => l.productId === ids.flour)!;
    const sugarLine = po.lines.find((l) => l.productId === ids.sugar)!;

    const results = await Promise.allSettled([
      mfg.receive({
        productId: ids.flour,
        qty: 500,
        uomId: gUom,
        unitCost: 30,
        poLineId: flourLine.id,
      }),
      mfg.receive({
        productId: ids.sugar,
        qty: 300,
        uomId: gUom,
        unitCost: 25,
        poLineId: sugarLine.id,
      }),
    ]);
    expect(results.every((r) => r.status === 'fulfilled')).toBe(true);

    const fresh = await mfg.getPurchaseOrder(po.id);
    expect(fresh.state).toBe('RECEIVED');
    expect(Number(fresh.lines.find((l) => l.productId === ids.flour)!.qtyReceived)).toBe(500);
    expect(Number(fresh.lines.find((l) => l.productId === ids.sugar)!.qtyReceived)).toBe(300);
    // Exactly one stock move per line — no double booking, no lost update.
    const moves = await prisma.mfgStockMove.findMany({
      where: { refType: 'RECEIPT', refId: po.id },
    });
    expect(moves).toHaveLength(2);
  });

  it('update-vs-confirm race: a confirmed PO can never end up with lines it did not confirm', async () => {
    const supplier = await mfg.createSupplier({ name: 'NCC Đua Sửa' });
    const po = await mfg.createPurchaseOrder({
      supplierId: supplier.id,
      lines: [{ productId: ids.flour, qty: 100, unitPrice: 30 }],
    });
    const [updRes] = await Promise.allSettled([
      mfg.updatePurchaseOrder(po.id, {
        lines: [{ productId: ids.sugar, qty: 999, unitPrice: 1 }],
      }),
      mfg.confirmPurchaseOrder(po.id),
    ]);
    const fresh = await mfg.getPurchaseOrder(po.id);
    expect(fresh.state).toBe('CONFIRMED');
    if (updRes.status === 'fulfilled') {
      // Update held the lock first (still DRAFT); confirm sealed the NEW lines.
      expect(fresh.lines[0].productId).toBe(ids.sugar);
    } else {
      // Confirm won — the edit was refused, original lines sealed.
      expect((updRes.reason as { status?: number }).status).toBe(400);
      expect(fresh.lines[0].productId).toBe(ids.flour);
    }
    // Deterministic tail: once CONFIRMED, edits are always refused.
    await expect(mfg.updatePurchaseOrder(po.id, { note: 'x' })).rejects.toMatchObject({
      status: 400,
    });
  });

  it('cancel-vs-receive race: stock is booked iff the receive won', async () => {
    const supplier = await mfg.createSupplier({ name: 'NCC Đua Huỷ' });
    const po = await mfg.createPurchaseOrder({
      supplierId: supplier.id,
      lines: [{ productId: ids.flour, qty: 200, unitPrice: 30 }],
    });
    await mfg.confirmPurchaseOrder(po.id);
    const before = await onHand(ids.flour);

    const [recvRes] = await Promise.allSettled([
      mfg.receive({
        productId: ids.flour,
        qty: 200,
        uomId: gUom,
        unitCost: 30,
        poLineId: po.lines[0].id,
      }),
      mfg.cancelPurchaseOrder(po.id),
    ]);

    const fresh = await mfg.getPurchaseOrder(po.id);
    if (recvRes.status === 'fulfilled') {
      // Receive held the lock first: full line in, RECEIVED; the concurrent
      // cancel then saw a closed PO and was refused.
      expect(Number(fresh.lines[0].qtyReceived)).toBe(200);
      expect(await onHand(ids.flour)).toBe(before + 200);
      expect(fresh.state).toBe('RECEIVED');
    } else {
      // Cancel won: the receipt was refused and NOTHING was booked.
      expect((recvRes.reason as { status?: number }).status).toBe(400);
      expect(Number(fresh.lines[0].qtyReceived)).toBe(0);
      expect(await onHand(ids.flour)).toBe(before);
      expect(fresh.state).toBe('CANCELLED');
    }
  });

  it('two concurrent confirms: exactly one transition wins', async () => {
    const supplier = await mfg.createSupplier({ name: 'NCC Đua Chốt' });
    const po = await mfg.createPurchaseOrder({
      supplierId: supplier.id,
      lines: [{ productId: ids.flour, qty: 10, unitPrice: 30 }],
    });
    const results = await Promise.allSettled([
      mfg.confirmPurchaseOrder(po.id),
      mfg.confirmPurchaseOrder(po.id),
    ]);
    const ok = results.filter((r) => r.status === 'fulfilled').length;
    const rejected = results.filter((r) => r.status === 'rejected') as PromiseRejectedResult[];
    expect(ok).toBe(1);
    expect(rejected).toHaveLength(1);
    expect((rejected[0].reason as { status?: number }).status).toBe(400);
    expect((await mfg.getPurchaseOrder(po.id)).state).toBe('CONFIRMED');
  });

  it('concurrent PO creates all succeed with distinct codes (sequence, no 500)', async () => {
    const supplier = await mfg.createSupplier({ name: 'NCC Đua Mã' });
    const pos = await Promise.all(
      Array.from({ length: 6 }, () =>
        mfg.createPurchaseOrder({
          supplierId: supplier.id,
          lines: [{ productId: ids.flour, qty: 1, unitPrice: 1 }],
        }),
      ),
    );
    const codes = new Set(pos.map((p) => p.code));
    expect(codes.size).toBe(6);
    for (const code of codes) expect(code).toMatch(/^PO-\d{5,}$/);
  });

  it('receipt against a PO line deleted mid-flight returns 404, not a Prisma 500', async () => {
    const supplier = await mfg.createSupplier({ name: 'NCC Dòng Ma' });
    const po = await mfg.createPurchaseOrder({
      supplierId: supplier.id,
      lines: [{ productId: ids.flour, qty: 50, unitPrice: 30 }],
    });
    await mfg.confirmPurchaseOrder(po.id);
    const before = await onHand(ids.flour);
    // Deterministic re-creation of the race window: the line row vanishes
    // right after the PO lock is taken but before the in-tx re-read — the
    // window a draft-edit-then-reconfirm hits when a receipt holds a stale
    // line id.
    const orig = (
      mfg as unknown as { lockPurchaseOrder: (db: unknown, id: string) => Promise<string> }
    ).lockPurchaseOrder.bind(mfg);
    const spy = jest
      .spyOn(mfg as unknown as { lockPurchaseOrder: typeof orig }, 'lockPurchaseOrder')
      .mockImplementation(async (db: unknown, poId: string) => {
        const state = await orig(db, poId);
        await prisma.mfgPurchaseOrderLine.deleteMany({ where: { id: po.lines[0].id } });
        return state;
      });
    try {
      await expect(
        mfg.receive({
          productId: ids.flour,
          qty: 50,
          uomId: gUom,
          unitCost: 30,
          poLineId: po.lines[0].id,
        }),
      ).rejects.toMatchObject({ status: 404 });
    } finally {
      spy.mockRestore();
    }
    // The refused receipt must book nothing.
    expect(await onHand(ids.flour)).toBe(before);
    expect((await mfg.getPurchaseOrder(po.id)).state).toBe('CONFIRMED');
  });

  it('draft PO supplier change is validated — no FK 500, no inactive supplier', async () => {
    const supplier = await mfg.createSupplier({ name: 'NCC Gốc' });
    const po = await mfg.createPurchaseOrder({
      supplierId: supplier.id,
      lines: [{ productId: ids.flour, qty: 5, unitPrice: 30 }],
    });
    // Nonexistent supplier: domain 400, not Prisma P2003 leaking as 500.
    await expect(
      mfg.updatePurchaseOrder(po.id, { supplierId: 'sup-khong-ton-tai' }),
    ).rejects.toMatchObject({ status: 400 });
    // Inactive supplier: refused, same rule as PO creation enforces.
    const retired = await mfg.createSupplier({ name: 'NCC Nghỉ' });
    await prisma.mfgSupplier.update({ where: { id: retired.id }, data: { active: false } });
    await expect(mfg.updatePurchaseOrder(po.id, { supplierId: retired.id })).rejects.toMatchObject({
      status: 400,
    });
    expect((await mfg.getPurchaseOrder(po.id)).supplierId).toBe(supplier.id);
    // A live supplier still swaps in fine.
    const fresh = await mfg.createSupplier({ name: 'NCC Mới' });
    expect((await mfg.updatePurchaseOrder(po.id, { supplierId: fresh.id })).supplierId).toBe(
      fresh.id,
    );
  });

  it('quality point creation validates its refs — bogus IDs are a 400, not a FK 500', async () => {
    await expect(
      mfg.createQualityPoint({
        titleVi: 'Đo nhiệt',
        titleEn: 'Temp check',
        testType: 'MEASURE',
        bomOperationId: 'op-khong-ton-tai',
      }),
    ).rejects.toMatchObject({ status: 400 });
    await expect(
      mfg.createQualityPoint({
        titleVi: 'Đo nhiệt',
        titleEn: 'Temp check',
        testType: 'MEASURE',
        productId: 'sp-khong-ton-tai',
      }),
    ).rejects.toMatchObject({ status: 400 });
    // Valid refs still create.
    const qp = await mfg.createQualityPoint({
      titleVi: 'Đo nhiệt',
      titleEn: 'Temp check',
      testType: 'MEASURE',
      productId: ids.flour,
    });
    expect(qp.productId).toBe(ids.flour);
  });

  it('cancelMO whose row vanished mid-flight stays idempotent, not a P2025 500', async () => {
    // The outer pre-read sees the MO, then the row is gone by the time the
    // transaction claims it (claim.count === 0, in-tx re-read finds nothing).
    const ghost = 'mo-da-bien-mat';
    const spy = jest
      .spyOn(prisma.mfgOrder, 'findUnique')
      .mockResolvedValueOnce({ id: ghost, state: 'CONFIRMED' } as never);
    try {
      await expect(mfg.cancelMO(ghost)).resolves.toMatchObject({ state: 'CANCEL' });
    } finally {
      spy.mockRestore();
    }
  });
});

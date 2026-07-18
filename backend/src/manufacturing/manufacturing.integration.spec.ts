import { PrismaClient } from '@prisma/client';

import { seedManufacturing } from '../../prisma/seed-manufacturing';

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

  let ids: Awaited<ReturnType<typeof seedManufacturing>>['ids'];
  let gUom: string;

  beforeAll(async () => {
    // Clean slate — order matters for FKs.
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
    await expect(
      mfg.planMO(cakeMo, { scheduledDate: when.toISOString() }),
    ).rejects.toThrow(/kết thúc/);
  });
});

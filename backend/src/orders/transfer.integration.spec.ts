// nanoid v5 is ESM-only — same shim the other orders specs use.
jest.mock('nanoid', () => ({ customAlphabet: () => () => 'test-id' }));

import { PrismaClient } from '@prisma/client';

import { seedManufacturing } from '../../prisma/seed-manufacturing';
import { ManufacturingService } from '../manufacturing/manufacturing.service';

import { OrdersService } from './orders.service';

/**
 * Race-condition proofs for internal transfers against a REAL Postgres:
 *  - kitchen adjust vs branch receive serialize on the Order row lock;
 *  - a COMPLETED order can never be adjusted;
 *  - the receipt, receivedQty and MES stock issue always reflect the same
 *    committed line quantities;
 *  - double receive books exactly one receipt + one MES issue;
 *  - createInternalTransfer retries are idempotent even after a product
 *    referenced by the original request was archived.
 *
 * Gated like manufacturing.integration: MFG_IT=1 DATABASE_URL=... jest transfer.integration
 */
const RUN = process.env.MFG_IT === '1' && !!process.env.DATABASE_URL;
const d = RUN ? describe : describe.skip;

d('Internal transfer adjust/receive races (integration)', () => {
  const prisma = new PrismaClient();
  const mfg = new ManufacturingService(prisma as never);
  const noop = {} as never;
  const realtime = { emit: jest.fn() };
  const notifications = {
    notifyKitchenStaff: jest.fn().mockResolvedValue(undefined),
  };
  const svc = new OrdersService(
    prisma as never,
    realtime as never,
    noop, // payments
    noop, // refunds
    noop, // loyalty
    noop, // coupons
    notifications as never,
    noop, // auth
    noop, // storeRouter
    noop, // deliveryConfig
    noop, // promotions
    mfg,
  );

  let ids: Awaited<ReturnType<typeof seedManufacturing>>['ids'];
  const run = `${Date.now()}`;
  let storeId: string;
  let kitchenId: string;
  let categoryId: string;
  let productId: string;
  let variantId: string;
  let ownerId: string;
  let kitchenUserId: string;
  const cleanupOrders: string[] = [];

  const kitchenActor = () => ({
    sub: kitchenUserId,
    role: 'KITCHEN_MANAGER' as const,
    kitchenId,
  });
  const storeActor = () => ({
    sub: ownerId,
    role: 'MERCHANT_OWNER' as const,
    storeId,
  });

  beforeAll(async () => {
    // MES clean slate + seed — same precedent as manufacturing.integration.
    // Retail-side references to MfgProduct go first (RESTRICT FKs).
    await prisma.internalTransferMfgItem.deleteMany();
    await prisma.mfgPurchaseOrderLine.deleteMany();
    await prisma.mfgPurchaseOrder.deleteMany();
    await prisma.mfgSupplier.deleteMany();
    await prisma.mfgReservation.deleteMany();
    await prisma.mfgMaintenance.deleteMany();
    await prisma.mfgQualityCheck.deleteMany();
    await prisma.mfgQualityAlert.deleteMany();
    await prisma.mfgQualityPoint.deleteMany();
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
    // The migration seeds STORE once in prod; the wipe above removed it here.
    await prisma.mfgLocation.create({
      data: {
        code: 'STORE',
        nameVi: 'Quầy cửa hàng',
        nameEn: 'Store counter',
        type: 'INTERNAL',
      },
    });
    // Stock to issue from.
    await mfg.receive({ productId: ids.flour, qty: 10_000, unitCost: 30 });
    await mfg.receive({ productId: ids.sugar, qty: 10_000, unitCost: 25 });

    const kitchen = await prisma.kitchen.create({
      data: { name: `Bếp IT ${run}`, address: 'test' },
    });
    kitchenId = kitchen.id;
    const store = await prisma.store.create({
      data: {
        name: `Chi nhánh IT ${run}`,
        slug: `it-transfer-${run}`,
        address: 'test',
        phone: '0000000000',
        openingHours: {},
        defaultKitchenId: kitchen.id,
      },
    });
    storeId = store.id;
    const category = await prisma.category.create({
      data: { name: `IT Cat ${run}`, slug: `it-cat-${run}` },
    });
    categoryId = category.id;
    const product = await prisma.product.create({
      data: {
        storeId,
        categoryId,
        name: `Bánh IT ${run}`,
        slug: `banh-it-${run}`,
        description: 'test',
        basePrice: 20000,
        images: [],
        variants: { create: [{ size: 'Default', flavor: 'Default' }] },
      },
      include: { variants: true },
    });
    productId = product.id;
    variantId = product.variants[0].id;
    const owner = await prisma.user.create({
      data: {
        email: `it-owner-${run}@banan.test`,
        passwordHash: 'x',
        fullName: 'Chủ IT',
        role: 'MERCHANT_OWNER',
        storeId,
      },
    });
    ownerId = owner.id;
    const kUser = await prisma.user.create({
      data: {
        email: `it-kitchen-${run}@banan.test`,
        passwordHash: 'x',
        fullName: 'Bếp IT',
        role: 'KITCHEN_MANAGER',
        kitchenId,
      },
    });
    kitchenUserId = kUser.id;
  });

  afterAll(async () => {
    // Only remove what this suite created — the DB doubles as a dev DB.
    try {
      const where = { orderId: { in: cleanupOrders } };
      await prisma.orderStatusEvent.deleteMany({ where });
      await prisma.internalTransferReceiptLine.deleteMany({
        where: { receipt: { orderId: { in: cleanupOrders } } },
      });
      await prisma.internalTransferReceipt.deleteMany({ where });
      await prisma.internalTransferMfgItem.deleteMany({ where });
      await prisma.orderItem.deleteMany({ where });
      await prisma.order.deleteMany({ where: { id: { in: cleanupOrders } } });
      await prisma.productVariant.deleteMany({ where: { productId } });
      await prisma.product.deleteMany({ where: { id: productId } });
      await prisma.category.deleteMany({ where: { id: categoryId } });
      await prisma.user.deleteMany({
        where: { id: { in: [ownerId, kitchenUserId] } },
      });
      await prisma.store.deleteMany({ where: { id: storeId } });
      await prisma.kitchen.deleteMany({ where: { id: kitchenId } });
    } finally {
      await prisma.$disconnect();
    }
  });

  /** Hand-built transfer at the branch-receivable stage. */
  async function makeTransfer() {
    const order = await prisma.order.create({
      data: {
        code: `ITT-${run}-${cleanupOrders.length}-${Math.floor(Math.random() * 1e6)}`,
        customerId: ownerId,
        storeId,
        fulfillmentType: 'DELIVERY',
        status: 'READY_FOR_PICKUP',
        kitchenId,
        source: 'INTERNAL_TRANSFER',
        settlementMode: 'INTERNAL_LEDGER',
        requestingStoreId: storeId,
        destinationStoreId: storeId,
        subtotal: 100000,
        total: 100000,
        items: {
          create: [
            {
              productId,
              variantId,
              productName: 'Bánh IT',
              quantity: 5,
              unitPrice: 20000,
              lineTotal: 100000,
            },
          ],
        },
        mfgItems: { create: [{ mfgProductId: ids.flour, qty: 100 }] },
      },
      include: { items: true, mfgItems: true },
    });
    cleanupOrders.push(order.id);
    return order;
  }

  const issuedFor = async (orderId: string) => {
    const moves = await prisma.mfgStockMove.findMany({
      where: { refType: 'INTERNAL', refId: orderId },
    });
    return moves.reduce((s, m) => s + Number(m.qty), 0);
  };

  it('rejects adjust after the order is COMPLETED', async () => {
    const order = await makeTransfer();
    await svc.receiveInternalTransfer(order.id, storeActor());
    await expect(
      svc.adjustInternalTransfer(order.id, kitchenActor(), {
        items: [{ orderItemId: order.items[0].id, quantity: 3 }],
      }),
    ).rejects.toMatchObject({ status: 400 });
    // Quantities untouched by the rejected adjust.
    const item = await prisma.orderItem.findUniqueOrThrow({
      where: { id: order.items[0].id },
    });
    expect(item.quantity).toBe(5);
  });

  it('adjust then receive: receipt + MES issue follow the ADJUSTED numbers', async () => {
    const order = await makeTransfer();
    await svc.adjustInternalTransfer(order.id, kitchenActor(), {
      items: [{ orderItemId: order.items[0].id, quantity: 3 }],
      mfgItems: [{ itemId: order.mfgItems[0].id, qty: 40 }],
      note: 'thiếu bột',
    });
    await svc.receiveInternalTransfer(order.id, storeActor());

    const receipt = await prisma.internalTransferReceipt.findUniqueOrThrow({
      where: { orderId: order.id },
      include: { lines: true },
    });
    expect(receipt.lines).toHaveLength(1);
    expect(receipt.lines[0].orderedQty).toBe(3);
    expect(receipt.lines[0].receivedQty).toBe(3);
    const mfgLine = await prisma.internalTransferMfgItem.findUniqueOrThrow({
      where: { id: order.mfgItems[0].id },
    });
    expect(Number(mfgLine.qty)).toBe(40);
    expect(Number(mfgLine.receivedQty)).toBe(40);
    expect(await issuedFor(order.id)).toBe(40);
    // Money followed the shipped quantities: 3 × 20 000.
    const fresh = await prisma.order.findUniqueOrThrow({ where: { id: order.id } });
    expect(Number(fresh.total)).toBe(60000);
  });

  it('concurrent adjust + receive: receipt/stock always match the final committed order', async () => {
    const order = await makeTransfer();
    const [adjustRes] = await Promise.allSettled([
      svc.adjustInternalTransfer(order.id, kitchenActor(), {
        items: [{ orderItemId: order.items[0].id, quantity: 2 }],
        mfgItems: [{ itemId: order.mfgItems[0].id, qty: 25 }],
      }),
      svc.receiveInternalTransfer(order.id, storeActor()),
    ]);

    const fresh = await prisma.order.findUniqueOrThrow({
      where: { id: order.id },
      include: { items: true, mfgItems: true },
    });
    expect(fresh.status).toBe('COMPLETED');
    const receipts = await prisma.internalTransferReceipt.findMany({
      where: { orderId: order.id },
      include: { lines: true },
    });
    expect(receipts).toHaveLength(1);
    // THE invariant: whichever side won, the receipt lines and the MES issue
    // were built from the same committed quantities the order ended with.
    expect(receipts[0].lines[0].orderedQty).toBe(fresh.items[0].quantity);
    expect(Number(fresh.mfgItems[0].receivedQty)).toBe(Number(fresh.mfgItems[0].qty));
    expect(await issuedFor(order.id)).toBe(Number(fresh.mfgItems[0].receivedQty));
    if (adjustRes.status === 'fulfilled') {
      expect(fresh.items[0].quantity).toBe(2);
      expect(Number(fresh.mfgItems[0].qty)).toBe(25);
    } else {
      // Receive won the lock first — adjust must have been refused cleanly.
      expect((adjustRes.reason as { status?: number }).status).toBe(400);
      expect(fresh.items[0].quantity).toBe(5);
      expect(Number(fresh.mfgItems[0].qty)).toBe(100);
    }
  });

  it('two concurrent receives: exactly one receipt, MES stock issued once', async () => {
    const order = await makeTransfer();
    const results = await Promise.allSettled([
      svc.receiveInternalTransfer(order.id, storeActor()),
      svc.receiveInternalTransfer(order.id, storeActor()),
    ]);
    const ok = results.filter((r) => r.status === 'fulfilled').length;
    expect(ok).toBe(1);
    const rejected = results.find((r) => r.status === 'rejected') as PromiseRejectedResult;
    expect((rejected.reason as { status?: number }).status).toBe(400);

    const receipts = await prisma.internalTransferReceipt.findMany({
      where: { orderId: order.id },
    });
    expect(receipts).toHaveLength(1);
    expect(await issuedFor(order.id)).toBe(100);
  });

  it('createInternalTransfer replay returns the original order even after the product was archived', async () => {
    const key = `it-replay-${run}-0001`;
    const first = await svc.createInternalTransfer(storeActor(), {
      items: [],
      mfgItems: [{ mfgProductId: ids.sugar, qty: 50 }],
      clientRequestId: key,
    });
    cleanupOrders.push(first.id);

    await prisma.mfgProduct.update({
      where: { id: ids.sugar },
      data: { active: false },
    });
    try {
      const replay = await svc.createInternalTransfer(storeActor(), {
        items: [],
        mfgItems: [{ mfgProductId: ids.sugar, qty: 50 }],
        clientRequestId: key,
      });
      expect(replay.id).toBe(first.id);
      const count = await prisma.order.count({
        where: { clientRequestId: key, customerId: ownerId },
      });
      expect(count).toBe(1);
    } finally {
      await prisma.mfgProduct.update({
        where: { id: ids.sugar },
        data: { active: true },
      });
    }
  });
});

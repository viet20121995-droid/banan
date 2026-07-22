import { ForbiddenException } from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';

jest.mock('nanoid', () => ({ customAlphabet: () => () => 'test-id' }));

import { OrdersService } from './orders.service';

/**
 * Policy tests for the operational channels (STAFF_COUNTER /
 * INTERNAL_TRANSFER): store scoping, trusted counter-customer resolution,
 * till settlement without any gateway, and the internal transfer's
 * no-customer/no-payment shape. DB-heavy behaviours (stock decrement race,
 * daily caps) are exercised by the shared helpers the WEB checkout already
 * covers; here we assert the channel WIRING is right.
 */

type PrismaMock = {
  order: { findUnique: jest.Mock; create?: jest.Mock };
  store: { findUnique: jest.Mock };
  user: { findUnique: jest.Mock; create: jest.Mock };
  product: { findMany: jest.Mock };
  storeBlackoutDate?: { findUnique: jest.Mock };
  $transaction: jest.Mock;
};

const decimal = (n: number) => new Prisma.Decimal(n);

function productFixture() {
  return {
    id: 'p1',
    storeId: 's1',
    name: 'Bánh kem dâu',
    basePrice: decimal(150000),
    isAvailable: true,
    leadTimeHours: null,
    availableDaysOfWeek: [] as number[],
    dailyMaxQuantity: null,
    flavorPickCount: null,
    flavorOptions: [] as string[],
    variants: [
      {
        id: 'v1',
        size: 'M',
        flavor: 'Dâu',
        priceDelta: decimal(0),
        isAvailable: true,
        stockMode: 'UNLIMITED',
        stockQty: null,
      },
    ],
  };
}

function orderRowFixture(over: Record<string, unknown> = {}) {
  return {
    id: 'o1',
    code: 'BAN-TEST-1',
    customerId: 'cust1',
    storeId: 's1',
    status: 'SENT_TO_KITCHEN',
    total: decimal(150000),
    currency: 'VND',
    createdAt: new Date(),
    items: [{ quantity: 1 }],
    ...over,
  };
}

function makeTxMock(orderCreate: jest.Mock, paymentCreate: jest.Mock) {
  return {
    $queryRaw: jest.fn((strings: TemplateStringsArray) => {
      const sql = strings.join('?');
      if (sql.includes('"Product"')) return Promise.resolve([{ id: 'p1', isAvailable: true }]);
      return Promise.resolve([{ id: 'v1', stockMode: 'UNLIMITED', isAvailable: true }]);
    }),
    $executeRaw: jest.fn().mockResolvedValue(1),
    order: { create: orderCreate },
    payment: { create: paymentCreate },
    productVariant: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
    orderItem: { aggregate: jest.fn().mockResolvedValue({ _sum: { quantity: 0 } }) },
  };
}

function makeService(prisma: PrismaMock) {
  const realtime = { emit: jest.fn(), evictStaleKitchenSubscribers: jest.fn() };
  const payments = {
    initiate: jest.fn(),
    validate: jest.fn(),
    onOrderCompleted: jest.fn().mockResolvedValue(undefined),
  };
  const notifications = {
    sendToUser: jest.fn().mockResolvedValue(undefined),
    notifyKitchenStaff: jest.fn().mockResolvedValue(undefined),
    notifyStoreStaff: jest.fn().mockResolvedValue(undefined),
  };
  const noop = {} as never;
  const loyalty = { earnFor: jest.fn().mockResolvedValue(undefined) };
  const svc = new OrdersService(
    prisma as never,
    realtime as never,
    payments as never,
    noop, // refunds
    loyalty as never,
    noop, // coupons
    notifications as never,
    noop, // auth
    noop, // storeRouter
    noop, // deliveryConfig
    noop, // promotions
    noop, // manufacturing
  );
  return { svc, realtime, payments, notifications };
}

function basePrisma(orderCreate: jest.Mock, paymentCreate: jest.Mock): PrismaMock {
  let storeCalls = 0;
  return {
    order: { findUnique: jest.fn().mockResolvedValue(null) },
    store: {
      // 1st call: the channel method's own store read (kitchen routing).
      // Later calls: assertStoreAcceptingOrder — null short-circuits it.
      findUnique: jest.fn(() => {
        storeCalls += 1;
        return Promise.resolve(storeCalls === 1 ? { id: 's1', defaultKitchenId: 'k1' } : null);
      }),
    },
    user: {
      findUnique: jest.fn().mockResolvedValue({ id: 'cust1', role: 'CUSTOMER' }),
      create: jest.fn(),
    },
    product: { findMany: jest.fn().mockResolvedValue([productFixture()]) },
    $transaction: jest.fn((cb: (tx: unknown) => unknown) =>
      cb(makeTxMock(orderCreate, paymentCreate)),
    ),
  };
}

const staff = { sub: 'staff1', role: Role.MERCHANT_STAFF, storeId: 's1' };

const counterDto = {
  items: [{ productId: 'p1', quantity: 1 }],
  customerName: 'Chị Mai',
  customerPhone: '0909111222',
  payment: 'PAID_AT_COUNTER' as const,
};

describe('createCounterOrder (STAFF_COUNTER)', () => {
  it('creates the order straight onto the kitchen board with a CASH payment — no gateway', async () => {
    const orderCreate = jest.fn().mockResolvedValue(orderRowFixture());
    const paymentCreate = jest.fn().mockResolvedValue({});
    const prisma = basePrisma(orderCreate, paymentCreate);
    const { svc, payments, notifications } = makeService(prisma);

    await svc.createCounterOrder(staff, counterDto);

    const data = orderCreate.mock.calls[0][0].data;
    expect(data.source).toBe('STAFF_COUNTER');
    expect(data.settlementMode).toBe('COUNTER_PAID');
    expect(data.createdById).toBe('staff1');
    expect(data.storeId).toBe('s1');
    expect(data.status).toBe('SENT_TO_KITCHEN');
    expect(data.kitchenStatus).toBe('PENDING_ACK');
    expect(data.kitchenId).toBe('k1');
    // Till cash recorded directly — the online payment pipeline is never touched.
    expect(paymentCreate).toHaveBeenCalledTimes(1);
    expect(paymentCreate.mock.calls[0][0].data).toMatchObject({
      provider: 'CASH',
      status: 'CAPTURED',
    });
    expect(payments.initiate).not.toHaveBeenCalled();
    expect(payments.validate).not.toHaveBeenCalled();
    expect(notifications.notifyKitchenStaff).toHaveBeenCalledWith(
      'k1',
      expect.anything(),
      expect.anything(),
    );
  });

  it('unpaid counter order records NO payment row', async () => {
    const orderCreate = jest.fn().mockResolvedValue(orderRowFixture());
    const paymentCreate = jest.fn();
    const prisma = basePrisma(orderCreate, paymentCreate);
    const { svc } = makeService(prisma);

    await svc.createCounterOrder(staff, { ...counterDto, payment: 'UNPAID_AT_COUNTER' });

    expect(orderCreate.mock.calls[0][0].data.settlementMode).toBe('COUNTER_UNPAID');
    expect(paymentCreate).not.toHaveBeenCalled();
  });

  it('staff cannot create for another store', async () => {
    const { svc } = makeService(basePrisma(jest.fn(), jest.fn()));
    await expect(
      svc.createCounterOrder(staff, { ...counterDto, storeId: 'OTHER' }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('admin must name a store', async () => {
    const { svc } = makeService(basePrisma(jest.fn(), jest.fn()));
    await expect(
      svc.createCounterOrder({ sub: 'adm', role: Role.ADMIN, storeId: null }, counterDto),
    ).rejects.toMatchObject({ response: { code: 'STORE_REQUIRED' } });
  });

  it('reuses a CLAIMED customer account for the phone (staff are trusted)', async () => {
    const orderCreate = jest.fn().mockResolvedValue(orderRowFixture());
    const prisma = basePrisma(orderCreate, jest.fn());
    prisma.user.findUnique = jest.fn().mockResolvedValue({ id: 'claimed1', role: 'CUSTOMER' });
    const { svc } = makeService(prisma);

    await svc.createCounterOrder(staff, counterDto);
    expect(orderCreate.mock.calls[0][0].data.customerId).toBe('claimed1');
    expect(prisma.user.create).not.toHaveBeenCalled();
  });

  it('refuses a staff/admin phone as the counter customer', async () => {
    const prisma = basePrisma(jest.fn(), jest.fn());
    prisma.user.findUnique = jest.fn().mockResolvedValue({ id: 'adm1', role: 'ADMIN' });
    const { svc } = makeService(prisma);

    await expect(svc.createCounterOrder(staff, counterDto)).rejects.toMatchObject({
      response: { code: 'PHONE_IS_STAFF' },
    });
  });

  it('replays the SAME order for a duplicate clientRequestId (no second create)', async () => {
    const existing = orderRowFixture({ id: 'first' });
    const orderCreate = jest.fn();
    const prisma = basePrisma(orderCreate, jest.fn());
    prisma.order.findUnique = jest.fn().mockResolvedValue(existing);
    const { svc } = makeService(prisma);

    const res = await svc.createCounterOrder(staff, {
      ...counterDto,
      clientRequestId: 'req-12345678',
    });
    expect(res).toBe(existing);
    expect(orderCreate).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
});

describe('createInternalTransfer (INTERNAL_TRANSFER)', () => {
  const transferDto = { items: [{ productId: 'p1', quantity: 2 }] };

  function transferPrisma(orderCreate: jest.Mock): PrismaMock {
    const prisma = basePrisma(orderCreate, jest.fn());
    // Both store reads (requesting + destination) must resolve.
    prisma.store.findUnique = jest.fn(({ where }: { where: { id: string } }) =>
      Promise.resolve({ id: where.id, defaultKitchenId: 'k1' }),
    );
    return prisma;
  }

  it('creates an internal order: no payment, INTERNAL_LEDGER, stores recorded, no customer notify', async () => {
    const orderCreate = jest
      .fn()
      .mockResolvedValue(orderRowFixture({ source: 'INTERNAL_TRANSFER' }));
    const prisma = transferPrisma(orderCreate);
    const { svc, notifications } = makeService(prisma);

    await svc.createInternalTransfer(staff, transferDto);

    const data = orderCreate.mock.calls[0][0].data;
    expect(data.source).toBe('INTERNAL_TRANSFER');
    expect(data.settlementMode).toBe('INTERNAL_LEDGER');
    expect(data.customerId).toBe('staff1'); // the requesting staffer stands in
    expect(data.requestingStoreId).toBe('s1');
    expect(data.destinationStoreId).toBe('s1');
    expect(data.status).toBe('SENT_TO_KITCHEN');
    expect(data.kitchenStatus).toBe('PENDING_ACK');
    // No coupons/points/gift cards can even be expressed — and no customer ping.
    expect(data.couponId).toBeUndefined();
    expect(data.pointsRedeemed).toBeUndefined();
    expect(data.giftCardCode).toBeUndefined();
    expect(notifications.sendToUser).not.toHaveBeenCalled();
    expect(notifications.notifyKitchenStaff).toHaveBeenCalled();
  });

  it('staff cannot request for another store', async () => {
    const { svc } = makeService(transferPrisma(jest.fn()));
    await expect(
      svc.createInternalTransfer(staff, { ...transferDto, requestingStoreId: 'OTHER' }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('admin may request for any store (explicit requestingStoreId)', async () => {
    const orderCreate = jest
      .fn()
      .mockResolvedValue(orderRowFixture({ source: 'INTERNAL_TRANSFER' }));
    const prisma = transferPrisma(orderCreate);
    const { svc } = makeService(prisma);

    await svc.createInternalTransfer(
      { sub: 'adm', role: Role.ADMIN, storeId: null },
      { ...transferDto, requestingStoreId: 's1', destinationStoreId: 's2' },
    );
    const data = orderCreate.mock.calls[0][0].data;
    expect(data.requestingStoreId).toBe('s1');
    expect(data.destinationStoreId).toBe('s2');
  });
});

describe('confirmWholesaleOrder', () => {
  function confirmationService({ claimed = 1, receivable = 1 } = {}) {
    const initial = {
      id: 'wo1',
      code: 'BAN-W-1',
      customerId: 'buyer1',
      storeId: 's1',
      source: 'WHOLESALE',
      status: 'PENDING',
      store: { id: 's1', defaultKitchenId: 'k1' },
      receivable: { id: 'r1', status: 'PENDING' },
      wholesaleAccount: { paymentTermDays: 30 },
      wholesaleContract: { paymentTermDays: 14 },
    };
    const updated = orderRowFixture({
      id: 'wo1',
      source: 'WHOLESALE',
      items: [{ quantity: 2 }],
    });
    const tx = {
      order: {
        updateMany: jest.fn().mockResolvedValue({ count: claimed }),
        findUniqueOrThrow: jest.fn().mockResolvedValue(updated),
      },
      wholesaleReceivable: {
        updateMany: jest.fn().mockResolvedValue({ count: receivable }),
      },
      orderStatusEvent: { createMany: jest.fn().mockResolvedValue({ count: 2 }) },
    };
    const prisma = {
      order: { findUnique: jest.fn().mockResolvedValue(initial) },
      $transaction: jest.fn((cb: (value: typeof tx) => unknown) => cb(tx)),
    };
    const { svc, realtime, notifications } = makeService(prisma as unknown as PrismaMock);
    return { svc, tx, realtime, notifications };
  }

  it('starts contract terms and sends the order to kitchen atomically', async () => {
    const { svc, tx, realtime, notifications } = confirmationService();
    const before = Date.now();

    await svc.confirmWholesaleOrder('wo1', { sub: 'adm', role: Role.ADMIN });

    expect(tx.order.updateMany).toHaveBeenCalledWith({
      where: { id: 'wo1', source: 'WHOLESALE', status: 'PENDING' },
      data: {
        status: 'SENT_TO_KITCHEN',
        kitchenStatus: 'PENDING_ACK',
        kitchenId: 'k1',
      },
    });
    const receivableData = tx.wholesaleReceivable.updateMany.mock.calls[0][0].data;
    expect(receivableData.status).toBe('OPEN');
    const dueMs = (receivableData.dueDate as Date).getTime() - before;
    expect(dueMs).toBeGreaterThan(13 * 24 * 3600 * 1000);
    expect(dueMs).toBeLessThan(15 * 24 * 3600 * 1000);
    expect(realtime.emit).toHaveBeenCalled();
    expect(notifications.notifyKitchenStaff).toHaveBeenCalledWith(
      'k1',
      expect.anything(),
      expect.anything(),
    );
  });

  it('does not activate debt when another confirmation wins the race', async () => {
    const { svc, tx } = confirmationService({ claimed: 0 });
    await expect(
      svc.confirmWholesaleOrder('wo1', { sub: 'adm', role: Role.ADMIN }),
    ).rejects.toMatchObject({ response: { code: 'ORDER_INVALID_TRANSITION' } });
    expect(tx.wholesaleReceivable.updateMany).not.toHaveBeenCalled();
  });
});

describe('markCounterPaid', () => {
  function paymentService(claimed = 1) {
    const order = orderRowFixture({
      source: 'STAFF_COUNTER',
      settlementMode: 'COUNTER_UNPAID',
    });
    const tx = {
      order: {
        updateMany: jest.fn().mockResolvedValue({ count: claimed }),
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          ...order,
          settlementMode: 'COUNTER_PAID',
        }),
      },
      payment: { create: jest.fn().mockResolvedValue({ id: 'pay1' }) },
    };
    const prisma = {
      order: { findUnique: jest.fn().mockResolvedValue(order) },
      $transaction: jest.fn((cb: (value: typeof tx) => unknown) => cb(tx)),
    };
    const { svc, realtime } = makeService(prisma as unknown as PrismaMock);
    return { svc, tx, realtime };
  }

  it('records till cash once and flips settlement atomically', async () => {
    const { svc, tx, realtime } = paymentService();
    await svc.markCounterPaid('o1', {
      sub: 'adm',
      role: Role.ADMIN,
    });
    expect(tx.order.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { settlementMode: 'COUNTER_PAID' },
      }),
    );
    expect(tx.payment.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        provider: 'CASH',
        status: 'CAPTURED',
        providerRef: 'COUNTER-BAN-TEST-1',
      }),
    });
    expect(realtime.emit).toHaveBeenCalled();
  });

  it('does not create a second cash payment on a racing retry', async () => {
    const { svc, tx } = paymentService(0);
    await expect(svc.markCounterPaid('o1', { sub: 'adm', role: Role.ADMIN })).rejects.toMatchObject(
      { response: { code: 'COUNTER_ALREADY_SETTLED' } },
    );
    expect(tx.payment.create).not.toHaveBeenCalled();
  });
});

describe('counter settlement gate on COMPLETED', () => {
  function txFor(order: Record<string, unknown>) {
    return {
      order: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        findUniqueOrThrow: jest.fn().mockResolvedValue(order),
      },
      orderStatusEvent: { create: jest.fn() },
      payment: { findMany: jest.fn().mockResolvedValue([]) },
    };
  }
  const unpaidCounter = orderRowFixture({
    source: 'STAFF_COUNTER',
    settlementMode: 'COUNTER_UNPAID',
    status: 'READY_FOR_PICKUP',
  });

  it('staff cannot COMPLETE an unpaid counter order', async () => {
    const prisma = {
      order: { findUnique: jest.fn().mockResolvedValue(unpaidCounter) },
      $transaction: jest.fn(),
    };
    const { svc } = makeService(prisma as never);
    await expect(
      svc.transition('o1', 'COMPLETED' as never, {
        sub: 'staff1',
        role: Role.MERCHANT_STAFF,
        storeId: 's1',
      }),
    ).rejects.toMatchObject({ response: { code: 'COUNTER_UNPAID_UNSETTLED' } });
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('admin override requires a reason', async () => {
    const prisma = {
      order: { findUnique: jest.fn().mockResolvedValue(unpaidCounter) },
      $transaction: jest.fn(),
    };
    const { svc } = makeService(prisma as never);
    await expect(
      svc.transition('o1', 'COMPLETED' as never, { sub: 'adm', role: Role.ADMIN }),
    ).rejects.toMatchObject({ response: { code: 'OVERRIDE_REASON_REQUIRED' } });
  });

  it('admin override WITH a reason completes', async () => {
    const prisma = {
      order: { findUnique: jest.fn().mockResolvedValue(unpaidCounter) },
      $transaction: jest.fn((cb: (t: unknown) => unknown) => cb(txFor(unpaidCounter))),
    };
    const { svc } = makeService(prisma as never);
    await expect(
      svc.transition(
        'o1',
        'COMPLETED' as never,
        { sub: 'adm', role: Role.ADMIN },
        'Khách chuyển khoản riêng',
      ),
    ).resolves.toBeDefined();
  });
});

describe('internal transfer destination lock + receive', () => {
  it('owner/staff cannot route goods to another store', async () => {
    const { svc } = makeService(basePrisma(jest.fn(), jest.fn()));
    await expect(
      svc.createInternalTransfer(staff, {
        items: [{ productId: 'p1', quantity: 1 }],
        destinationStoreId: 'OTHER',
      }),
    ).rejects.toMatchObject({ response: { code: 'STORE_SCOPE' } });
  });

  const dispatched = orderRowFixture({
    source: 'INTERNAL_TRANSFER',
    status: 'READY_FOR_PICKUP',
    destinationStoreId: 's2',
    items: [{ id: 'oi1', productName: 'Bánh mì', quantity: 10 }],
  });

  it('only the DESTINATION store may sign for the goods', async () => {
    const prisma = {
      order: { findUnique: jest.fn().mockResolvedValue(dispatched) },
      $transaction: jest.fn(),
    };
    const { svc } = makeService(prisma as never);
    await expect(
      svc.receiveInternalTransfer('o1', {
        sub: 'staff1',
        role: Role.MERCHANT_STAFF,
        storeId: 's1',
      }),
    ).rejects.toMatchObject({ response: { code: 'NOT_DESTINATION_STORE' } });
  });

  it('destination store confirms receipt (with shortages) and the order completes', async () => {
    const statusEventCreate = jest.fn();
    const receiptCreate = jest.fn().mockResolvedValue({ id: 'rcpt1' });
    // receive() now locks the row and re-reads the lines INSIDE the
    // transaction (adjust-vs-receive race fix), so the tx stub serves the
    // lock query and the fresh line reads too.
    const tx = {
      $queryRaw: jest.fn().mockResolvedValue([{ status: 'READY_FOR_PICKUP' }]),
      order: {
        update: jest.fn().mockResolvedValue({ count: 1 }),
        findUniqueOrThrow: jest.fn().mockResolvedValue({ ...dispatched, status: 'COMPLETED' }),
      },
      orderItem: {
        findMany: jest.fn().mockResolvedValue(dispatched.items),
      },
      internalTransferMfgItem: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      orderStatusEvent: { create: statusEventCreate },
      internalTransferReceipt: { create: receiptCreate },
    };
    const prisma = {
      order: { findUnique: jest.fn().mockResolvedValue(dispatched) },
      $transaction: jest.fn((cb: (t: unknown) => unknown) => cb(tx)),
    };
    const { svc } = makeService(prisma as never);
    await svc.receiveInternalTransfer(
      'o1',
      { sub: 'dest1', role: Role.MERCHANT_OWNER, storeId: 's2' },
      { items: [{ orderItemId: 'oi1', receivedQty: 8 }], note: 'Vỡ 2 hộp.' },
    );
    const ev = statusEventCreate.mock.calls[0][0].data;
    expect(ev.toStatus).toBe('COMPLETED');
    expect(ev.actorId).toBe('dest1');
    expect(ev.note).toContain('nhận 8/10');
    expect(ev.note).toContain('Vỡ 2 hộp');
    // Structured receipt: per-line ordered vs received, receiver recorded.
    const receipt = receiptCreate.mock.calls[0][0].data;
    expect(receipt.receivedById).toBe('dest1');
    expect(receipt.lines.createMany.data).toEqual([
      { orderItemId: 'oi1', orderedQty: 10, receivedQty: 8 },
    ]);
  });
});

describe('destination-store visibility', () => {
  it('the merchant list includes transfers the store RECEIVES, not just fulfils', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const count = jest.fn().mockResolvedValue(0);
    const prisma = {
      order: { findMany, count },
      $transaction: jest.fn((ops: Array<Promise<unknown>>) => Promise.all(ops)),
    };
    const { svc } = makeService(prisma as never);
    await svc.listForStore('s2', {});
    const where = findMany.mock.calls[0][0].where;
    expect(where.OR).toEqual([
      { storeId: 's2' },
      { source: 'INTERNAL_TRANSFER', destinationStoreId: 's2' },
    ]);
  });
});

describe('customer-facing notifications are gated for INTERNAL_TRANSFER', () => {
  it('transition() skips sendToUser for internal transfers', async () => {
    const order = orderRowFixture({
      source: 'INTERNAL_TRANSFER',
      status: 'SENT_TO_KITCHEN',
      kitchenId: 'k1',
    });
    const tx = {
      order: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        findUniqueOrThrow: jest.fn().mockResolvedValue(order),
      },
      orderStatusEvent: { create: jest.fn() },
      payment: { findMany: jest.fn().mockResolvedValue([]) },
    };
    const prisma = {
      order: { findUnique: jest.fn().mockResolvedValue(order) },
      $transaction: jest.fn((cb: (t: unknown) => unknown) => cb(tx)),
    };
    const { svc, notifications } = makeService(prisma as never);

    await svc.transition('o1', 'IN_PREPARATION' as never, {
      sub: 'adm',
      role: Role.ADMIN,
    });
    expect(notifications.sendToUser).not.toHaveBeenCalled();
  });
});

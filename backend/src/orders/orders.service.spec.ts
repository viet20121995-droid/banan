import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

// `nanoid` is ESM-only and is pulled in transitively (orders → payments →
// momo). Replace it with a CJS stub so Jest can load the module graph. It's
// not exercised here — upsertGuestCustomer uses node:crypto randomBytes.
jest.mock('nanoid', () => ({ customAlphabet: () => () => 'test-id' }));

import { OrdersService } from './orders.service';

/**
 * Security-focused unit tests for the guest-checkout identity resolution
 * (`OrdersService.upsertGuestCustomer`). This decides whether an
 * unauthenticated guest order binds to an existing account — the anti-takeover
 * gate — so it gets a dedicated spec even though the method is private.
 */

type GuestArgs = { fullName: string; phone: string; email?: string };
type UpsertResult = { userId: string; createdNew: boolean };

function makeService(prismaUser: {
  findUnique?: jest.Mock;
  create?: jest.Mock;
}) {
  const prisma = {
    user: {
      findUnique: prismaUser.findUnique ?? jest.fn().mockResolvedValue(null),
      create: prismaUser.create ?? jest.fn(),
    },
  };
  const noop = {} as never;
  // Only `prisma` (the 1st ctor arg) is exercised by upsertGuestCustomer; the
  // remaining collaborators are never touched, so inert stubs are fine.
  const svc = new OrdersService(
    prisma as never,
    noop, // realtime
    noop, // payments
    noop, // refunds
    noop, // loyalty
    noop, // coupons
    noop, // notifications
    noop, // auth
    noop, // storeRouter
    noop, // deliveryConfig
    noop, // promotions
  );
  return { svc, prisma };
}

const upsert = (svc: OrdersService, args: GuestArgs): Promise<UpsertResult> =>
  (
    svc as unknown as {
      upsertGuestCustomer(a: GuestArgs): Promise<UpsertResult>;
    }
  ).upsertGuestCustomer(args);

/** Route findUnique by which unique key the call used (phone vs email). */
function findUniqueRouter(opts: {
  byPhone?: unknown;
  byEmail?: unknown;
}): jest.Mock {
  return jest.fn((args: { where: { phone?: string; email?: string } }) => {
    if (args.where.phone !== undefined) {
      return Promise.resolve(opts.byPhone ?? null);
    }
    if (args.where.email !== undefined) {
      return Promise.resolve(opts.byEmail ?? null);
    }
    return Promise.resolve(null);
  });
}

async function expectPhoneHasAccount(p: Promise<unknown>): Promise<void> {
  await expect(p).rejects.toBeInstanceOf(BadRequestException);
  await p.catch((e: BadRequestException) => {
    expect((e.getResponse() as { code?: string }).code).toBe(
      'PHONE_HAS_ACCOUNT',
    );
  });
}

describe('OrdersService.upsertGuestCustomer (anti-takeover)', () => {
  it('creates a fresh guest CUSTOMER when the phone is unused', async () => {
    const create = jest.fn().mockResolvedValue({ id: 'new-1' });
    const { svc, prisma } = makeService({
      findUnique: findUniqueRouter({ byPhone: null }),
      create,
    });

    const res = await upsert(svc, { fullName: 'Khách Mới', phone: '0909000001' });

    expect(res).toEqual({ userId: 'new-1', createdNew: true });
    expect(create).toHaveBeenCalledTimes(1);
    const data = create.mock.calls[0][0].data;
    expect(data.role).toBe('CUSTOMER');
    expect(data.phone).toBe('0909000001');
    // Must NOT be born claimed — a guest stub stays unclaimed.
    expect(data.claimed).toBeUndefined();
    expect(prisma.user.create).toHaveBeenCalled();
  });

  it('reuses an UNCLAIMED, CUSTOMER-role stub (returning guest)', async () => {
    const create = jest.fn();
    const { svc } = makeService({
      findUnique: findUniqueRouter({
        byPhone: { id: 'stub-1', claimed: false, role: 'CUSTOMER' },
      }),
      create,
    });

    const res = await upsert(svc, {
      fullName: 'Khách Quen',
      phone: '0909000002',
    });

    expect(res).toEqual({ userId: 'stub-1', createdNew: false });
    expect(create).not.toHaveBeenCalled();
  });

  it('REFUSES a phone that belongs to a CLAIMED account', async () => {
    const create = jest.fn();
    const { svc } = makeService({
      findUnique: findUniqueRouter({
        byPhone: { id: 'real-1', claimed: true, role: 'CUSTOMER' },
      }),
      create,
    });

    await expectPhoneHasAccount(
      upsert(svc, { fullName: 'Kẻ Gian', phone: '0900111222' }),
    );
    expect(create).not.toHaveBeenCalled();
  });

  it('REFUSES a phone on a non-CUSTOMER account even if unclaimed (staff/kitchen/admin)', async () => {
    const create = jest.fn();
    const { svc } = makeService({
      findUnique: findUniqueRouter({
        byPhone: { id: 'merchant-1', claimed: false, role: 'MERCHANT_OWNER' },
      }),
      create,
    });

    await expectPhoneHasAccount(
      upsert(svc, { fullName: 'Ai Đó', phone: '0900333444' }),
    );
    expect(create).not.toHaveBeenCalled();
  });

  it('synthesises a unique guest email when the supplied one is taken', async () => {
    const create = jest.fn().mockResolvedValue({ id: 'new-2' });
    const { svc } = makeService({
      findUnique: findUniqueRouter({
        byPhone: null,
        byEmail: { id: 'someone-else' }, // email already in use
      }),
      create,
    });

    await upsert(svc, {
      fullName: 'Trùng Email',
      phone: '0909000003',
      email: 'taken@example.com',
    });

    const data = create.mock.calls[0][0].data;
    expect(data.email).toMatch(/^guest\+[0-9a-f]+@banan\.local$/);
  });
});

/**
 * The status-guarded transition: a concurrent (lost-race) cancel must NOT run
 * the cancellation side-effects (refund points / restock / reverse coupon +
 * campaign), or they'd double-apply.
 */
describe('OrdersService.transition (status-guarded)', () => {
  const ADMIN = { sub: 'a1', role: 'ADMIN' as const };
  const order = {
    id: 'o1',
    status: 'PENDING',
    customerId: 'c1',
    storeId: 's1',
    kitchenId: null,
  };

  function makeTxService(updateManyCount: number) {
    const loyalty = {
      refundRedemption: jest.fn().mockResolvedValue(undefined),
      earnFor: jest.fn().mockResolvedValue(undefined),
    };
    const payments = {
      onOrderCancelled: jest.fn().mockResolvedValue({ capturedPayments: [] }),
      onOrderCompleted: jest.fn().mockResolvedValue(undefined),
    };
    const coupons = {
      reverseRedemption: jest.fn().mockResolvedValue(undefined),
    };
    const promotions = { reverseUsage: jest.fn().mockResolvedValue(undefined) };
    // The tx client must expose every delegate the in-tx side-effects touch:
    // status update + event, plus restoreInventory (orderItem/variant) and
    // restoreGiftCard (order.findUnique/giftCard) which now run on `tx`.
    const tx = {
      order: {
        updateMany: jest.fn().mockResolvedValue({ count: updateManyCount }),
        findUniqueOrThrow: jest.fn().mockResolvedValue(order),
        findUnique: jest.fn().mockResolvedValue(order), // no giftCardCode → no-op
      },
      orderStatusEvent: { create: jest.fn().mockResolvedValue({}) },
      orderItem: { findMany: jest.fn().mockResolvedValue([]) },
      productVariant: { update: jest.fn().mockResolvedValue({}) },
      giftCard: { updateMany: jest.fn().mockResolvedValue({ count: 0 }) },
    };
    const prisma = {
      order: { findUnique: jest.fn().mockResolvedValue(order) },
      $transaction: jest.fn(
        (cb: (t: unknown) => unknown, _opts?: unknown) => cb(tx),
      ),
    };
    const noop = {} as never;
    const svc = new OrdersService(
      prisma as never,
      { emit: jest.fn() } as never, // realtime
      payments as never,
      noop, // refunds
      loyalty as never,
      coupons as never,
      { sendToUser: jest.fn() } as never, // notifications
      noop, // auth
      noop, // storeRouter
      noop, // deliveryConfig
      promotions as never,
    );
    return { svc, tx, loyalty, payments, coupons, promotions };
  }

  it('lost race (status-guard count 0) → throws, runs NO side-effects', async () => {
    const m = makeTxService(0);
    await expect(
      m.svc.transition('o1', 'CANCELLED', ADMIN),
    ).rejects.toMatchObject({ response: { code: 'ORDER_INVALID_TRANSITION' } });
    expect(m.tx.order.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 'o1', status: 'PENDING' } }),
    );
    expect(m.loyalty.refundRedemption).not.toHaveBeenCalled();
    expect(m.payments.onOrderCancelled).not.toHaveBeenCalled();
    expect(m.coupons.reverseRedemption).not.toHaveBeenCalled();
    expect(m.promotions.reverseUsage).not.toHaveBeenCalled();
  });

  it('won race (count 1) → reverses coupon + campaign exactly once', async () => {
    const m = makeTxService(1);
    await m.svc.transition('o1', 'CANCELLED', ADMIN);
    expect(m.loyalty.refundRedemption).toHaveBeenCalledTimes(1);
    expect(m.coupons.reverseRedemption).toHaveBeenCalledTimes(1);
    expect(m.promotions.reverseUsage).toHaveBeenCalledTimes(1);
  });
});

describe('OrdersService.dispatchFromKitchen (no resurrect of a cancelled order)', () => {
  const ADMIN = { sub: 'a1', role: 'ADMIN' as const, kitchenId: null };

  function svcWith(order: unknown) {
    const prisma = {
      order: { findUnique: jest.fn().mockResolvedValue(order) },
      $transaction: jest.fn(),
    };
    const noop = {} as never;
    const svc = new OrdersService(
      prisma as never,
      noop,
      noop,
      noop,
      noop,
      noop,
      noop,
      noop,
      noop,
      noop,
      noop,
    );
    return { svc, prisma };
  }

  it('refuses a CANCELLED order even at kitchenStatus READY_DISPATCH — no status write', async () => {
    const m = svcWith({
      id: 'o1',
      status: 'CANCELLED',
      kitchenStatus: 'READY_DISPATCH',
      kitchenId: null,
      fulfillmentType: 'PICKUP',
      customerId: 'c1',
      storeId: 's1',
    });
    await expect(
      m.svc.dispatchFromKitchen('o1', ADMIN),
    ).rejects.toMatchObject({ response: { code: 'KITCHEN_NOT_READY' } });
    // Threw before the transaction → the order is never flipped back to a live
    // status (no resurrection).
    expect(m.prisma.$transaction).not.toHaveBeenCalled();
  });
});

/**
 * Kitchen routing authz. Kitchens are CENTRAL (one kitchen serves many stores
 * via Store.defaultKitchenId), so there is no per-kitchen storeId to scope
 * against. A store merchant must therefore be confined to their own store's
 * kitchen — otherwise they could hand-craft a transfer to another store's
 * kitchen and leak the order (customer name/phone/address/items) onto its
 * board. Only an admin (chain operator) may direct an order to another kitchen,
 * and even then the kitchen must exist.
 */
describe('OrdersService.transferToKitchen (kitchen routing authz)', () => {
  function svcWith(opts: { kitchenCount?: number }) {
    const order = {
      id: 'o1',
      status: 'ACCEPTED',
      code: 'BN-1',
      customerId: 'c1',
      storeId: 's1',
      kitchenId: null,
      items: [],
      store: { id: 's1', name: 'S1', slug: 's1', defaultKitchenId: 'k1' },
    };
    const prisma = {
      order: { findUnique: jest.fn().mockResolvedValue(order) },
      kitchen: { count: jest.fn().mockResolvedValue(opts.kitchenCount ?? 1) },
      $transaction: jest.fn(),
    };
    const noop = {} as never;
    const svc = new OrdersService(
      prisma as never,
      noop,
      noop,
      noop,
      noop,
      noop,
      noop,
      noop,
      noop,
      noop,
      noop,
    );
    return { svc, prisma };
  }

  it('rejects a merchant routing to a kitchen that is not their store default', async () => {
    const m = svcWith({});
    const MERCHANT = {
      sub: 'm1',
      role: 'MERCHANT_OWNER' as const,
      storeId: 's1',
    };
    await expect(
      m.svc.transferToKitchen('o1', MERCHANT, { kitchenId: 'k2' }),
    ).rejects.toMatchObject({ response: { code: 'KITCHEN_NOT_ALLOWED' } });
    // Rejected before any DB write — and before we even probe kitchen existence.
    expect(m.prisma.$transaction).not.toHaveBeenCalled();
    expect(m.prisma.kitchen.count).not.toHaveBeenCalled();
  });

  it('rejects an admin routing to a non-existent kitchen', async () => {
    const m = svcWith({ kitchenCount: 0 });
    const ADMIN = { sub: 'a1', role: 'ADMIN' as const, storeId: null };
    await expect(
      m.svc.transferToKitchen('o1', ADMIN, { kitchenId: 'ghost' }),
    ).rejects.toMatchObject({ response: { code: 'KITCHEN_NOT_FOUND' } });
    expect(m.prisma.$transaction).not.toHaveBeenCalled();
  });
});

/**
 * Timeline validation must surface EVERY offending cake (not just the first),
 * so the customer can see exactly which items don't fit their chosen time.
 * `assertProductsAcceptingOrder` is pure (no `this`), so we invoke it via the
 * prototype with a throwaway receiver.
 */
describe('OrdersService.assertProductsAcceptingOrder (aggregated timeline)', () => {
  type P = {
    id: string;
    name: string;
    leadTimeHours: number | null;
    availableDaysOfWeek: number[];
  };
  const run = (products: P[], at: Date, placedAt: Date, scheduled: boolean) =>
    (
      OrdersService.prototype as unknown as {
        assertProductsAcceptingOrder(
          p: P[],
          at: Date,
          placedAt: Date,
          s: boolean,
        ): Promise<void>;
      }
    ).assertProductsAcceptingOrder.call({}, products, at, placedAt, scheduled);

  // A Wednesday (VN) baseline. 2024-01-03T03:00:00Z = 10:00 VN, weekday 3.
  const placedAt = new Date('2024-01-03T03:00:00Z');

  it('passes when every item fits (no lead time, day allowed)', async () => {
    await expect(
      run(
        [{ id: 'a', name: 'A', leadTimeHours: 0, availableDaysOfWeek: [] }],
        placedAt,
        placedAt,
        false,
      ),
    ).resolves.toBeUndefined();
  });

  it('aggregates ALL offenders (lead-time + day) into one ORDER_ITEMS_TIMELINE error', async () => {
    const products: P[] = [
      { id: 'ok', name: 'Sẵn có', leadTimeHours: 0, availableDaysOfWeek: [] },
      { id: 'lead', name: 'Bánh kem', leadTimeHours: 48, availableDaysOfWeek: [] },
      // Wednesday is weekday 3; this one only sells Sat(6)/Sun(0).
      { id: 'day', name: 'Bánh cuối tuần', leadTimeHours: 0, availableDaysOfWeek: [0, 6] },
    ];
    // Ordering "now" (placedAt == at) → the 48h item fails lead time.
    const err = await run(products, placedAt, placedAt, false).catch((e) => e);
    expect(err).toBeInstanceOf(BadRequestException);
    const body = (err as BadRequestException).getResponse() as {
      code: string;
      details: { items: Array<Record<string, unknown>>; earliestLeadHours?: number };
    };
    expect(body.code).toBe('ORDER_ITEMS_TIMELINE');
    expect(body.details.items).toHaveLength(2); // both offenders, not just first
    expect(body.details.items.map((i) => i.productId).sort()).toEqual(['day', 'lead']);
    expect(body.details.earliestLeadHours).toBe(48);
    const lead = body.details.items.find((i) => i.productId === 'lead');
    expect(lead).toMatchObject({ reason: 'LEAD_TIME', leadTimeHours: 48 });
    const day = body.details.items.find((i) => i.productId === 'day');
    expect(day).toMatchObject({ reason: 'DAY_UNAVAILABLE', availableDaysOfWeek: [0, 6] });
  });

  it('reports DAY_UNAVAILABLE (not lead) when the chosen day is wrong, even if lead would also fail', async () => {
    // Item sells only Sat/Sun and needs 48h. On a Wednesday order, the day
    // constraint takes precedence and lead time is not double-reported.
    const products: P[] = [
      { id: 'x', name: 'X', leadTimeHours: 48, availableDaysOfWeek: [0, 6] },
    ];
    const err = await run(products, placedAt, placedAt, true).catch((e) => e);
    const body = (err as BadRequestException).getResponse() as {
      details: { items: Array<{ reason: string }>; earliestLeadHours?: number };
    };
    expect(body.details.items).toHaveLength(1);
    expect(body.details.items[0].reason).toBe('DAY_UNAVAILABLE');
    expect(body.details.earliestLeadHours).toBeUndefined();
  });

  it('passes lead time when scheduled far enough ahead', async () => {
    const at = new Date(placedAt.getTime() + 50 * 3600 * 1000); // +50h, still a valid weekday set (empty)
    await expect(
      run(
        [{ id: 'lead', name: 'Bánh kem', leadTimeHours: 48, availableDaysOfWeek: [] }],
        at,
        placedAt,
        true,
      ),
    ).resolves.toBeUndefined();
  });
});

/**
 * Combo (Bundle) lines must expand into their constituent products at REGULAR
 * prices, with the combo savings reported once as bundleDiscount. Pure helper,
 * invoked via the prototype.
 */
describe('OrdersService.expandLineInputs (combo expansion + pricing)', () => {
  const dec = (n: number) => new Prisma.Decimal(n);
  const expand = (
    items: Array<{
      productId: string;
      variantId?: string | null;
      quantity: number;
      customMessage?: string | null;
      personalization?: Record<string, unknown> | null;
    }>,
    bundleById: Map<string, unknown>,
  ): { lines: Array<Record<string, unknown>>; bundleDiscount: Prisma.Decimal } =>
    (
      OrdersService.prototype as unknown as {
        expandLineInputs(i: unknown, b: unknown): {
          lines: Array<Record<string, unknown>>;
          bundleDiscount: Prisma.Decimal;
        };
      }
    ).expandLineInputs.call({}, items, bundleById);

  // Bundle with two parts, each one variant. basePrice + priceDelta = unit.
  const comboAB = {
    name: 'Combo A+B',
    priceVnd: 100000,
    items: [
      { quantity: 1, product: { id: 'p1', basePrice: dec(60000), variants: [{ id: 'p1v', priceDelta: dec(0) }] }, variant: null },
      { quantity: 1, product: { id: 'p2', basePrice: dec(60000), variants: [{ id: 'p2v', priceDelta: dec(0) }] }, variant: null },
    ],
  };

  it('passes plain product lines through untouched (fromBundle false, no discount)', () => {
    const { lines, bundleDiscount } = expand(
      [{ productId: 'x', variantId: 'xv', quantity: 3 }],
      new Map(),
    );
    expect(lines).toHaveLength(1);
    expect(lines[0]).toMatchObject({ productId: 'x', variantId: 'xv', quantity: 3, fromBundle: false });
    expect(bundleDiscount.toNumber()).toBe(0);
  });

  it('expands a combo into its parts at regular price + records the savings', () => {
    const { lines, bundleDiscount } = expand(
      [{ productId: 'cAB', quantity: 1 }],
      new Map([['cAB', comboAB]]),
    );
    expect(lines).toHaveLength(2);
    expect(lines.every((l) => l.fromBundle === true)).toBe(true);
    expect(lines.map((l) => l.productId).sort()).toEqual(['p1', 'p2']);
    expect(lines.map((l) => l.quantity)).toEqual([1, 1]);
    // regular 120k − combo 100k = 20k saved.
    expect(bundleDiscount.toNumber()).toBe(20000);
  });

  it('scales quantities and savings by the combo quantity', () => {
    const { lines, bundleDiscount } = expand(
      [{ productId: 'cAB', quantity: 2 }],
      new Map([['cAB', comboAB]]),
    );
    expect(lines.map((l) => l.quantity)).toEqual([2, 2]);
    expect(bundleDiscount.toNumber()).toBe(40000); // (120k − 100k) × 2
  });

  it('uses the bundle item variant when set, else the product first variant', () => {
    const combo = {
      name: 'C',
      priceVnd: 50000,
      items: [
        {
          quantity: 1,
          product: { id: 'p', basePrice: dec(40000), variants: [{ id: 'small', priceDelta: dec(0) }, { id: 'big', priceDelta: dec(20000) }] },
          variant: { id: 'big', priceDelta: dec(20000) }, // explicit → 60k
        },
      ],
    };
    const { lines, bundleDiscount } = expand([{ productId: 'c', quantity: 1 }], new Map([['c', combo]]));
    expect(lines[0]).toMatchObject({ productId: 'p', variantId: 'big', quantity: 1 });
    expect(bundleDiscount.toNumber()).toBe(10000); // 60k − 50k
  });

  it('rejects at order time when the combo price now exceeds the regular sum (component prices dropped)', () => {
    const overpriced = { ...comboAB, priceVnd: 200000 }; // > 120k regular
    expect(() =>
      expand([{ productId: 'cAB', quantity: 1 }], new Map([['cAB', overpriced]])),
    ).toThrow(BadRequestException);
  });

  it('handles a mix of a plain product and a combo', () => {
    const { lines, bundleDiscount } = expand(
      [
        { productId: 'x', variantId: 'xv', quantity: 1 },
        { productId: 'cAB', quantity: 1 },
      ],
      new Map([['cAB', comboAB]]),
    );
    expect(lines).toHaveLength(3);
    expect(lines.filter((l) => l.fromBundle).length).toBe(2);
    expect(lines.filter((l) => !l.fromBundle).length).toBe(1);
    expect(bundleDiscount.toNumber()).toBe(20000);
  });

  it('rejects a combo whose item has no usable variant', () => {
    const broken = {
      name: 'Broken',
      priceVnd: 10000,
      items: [{ quantity: 1, product: { id: 'p', basePrice: dec(10000), variants: [] }, variant: null }],
    };
    expect(() => expand([{ productId: 'b', quantity: 1 }], new Map([['b', broken]]))).toThrow(
      BadRequestException,
    );
  });
});

/**
 * Product.dailyMaxQuantity — a per-product cap on units ordered for one
 * fulfilment date, across all customers (combo-expanded units count too). The
 * check is private and runs inside the order tx; we invoke it via the prototype
 * with a mock tx (advisory lock + aggregate).
 */
describe('OrdersService.assertDailyCaps (per-product daily order cap)', () => {
  type DailyProduct = {
    id: string;
    name: string;
    dailyMaxQuantity: number | null;
  };
  function txWith(existing: number) {
    return {
      $executeRaw: jest.fn().mockResolvedValue(0),
      orderItem: {
        aggregate: jest
          .fn()
          .mockResolvedValue({ _sum: { quantity: existing } }),
      },
    };
  }
  const call = (
    tx: unknown,
    products: DailyProduct[],
    qty: Map<string, number>,
    targetAt: Date,
  ): Promise<void> =>
    (
      OrdersService.prototype as unknown as {
        assertDailyCaps(
          t: unknown,
          p: DailyProduct[],
          q: Map<string, number>,
          a: Date,
        ): Promise<void>;
      }
    ).assertDailyCaps.call({}, tx, products, qty, targetAt);

  const DAY = new Date('2026-06-20T03:00:00Z');

  it('rejects when existing + requested exceeds the cap (locks first)', async () => {
    const tx = txWith(8); // 8 already ordered for the day
    await expect(
      call(
        tx,
        [{ id: 'p1', name: 'Chiffon', dailyMaxQuantity: 10 }],
        new Map([['p1', 5]]), // 8 + 5 = 13 > 10
        DAY,
      ),
    ).rejects.toMatchObject({ response: { code: 'DAILY_LIMIT_EXCEEDED' } });
    // The per-(product,date) advisory lock is taken before counting.
    expect(tx.$executeRaw).toHaveBeenCalledTimes(1);
  });

  it('allows within the cap and skips uncapped products entirely', async () => {
    const tx = txWith(3);
    await expect(
      call(
        tx,
        [
          { id: 'p1', name: 'Chiffon', dailyMaxQuantity: 10 }, // 3 + 5 = 8 ≤ 10
          { id: 'p2', name: 'Tart', dailyMaxQuantity: null }, // uncapped → skip
        ],
        new Map([
          ['p1', 5],
          ['p2', 99],
        ]),
        DAY,
      ),
    ).resolves.toBeUndefined();
    // Only the capped product is locked + aggregated.
    expect(tx.$executeRaw).toHaveBeenCalledTimes(1);
    expect(tx.orderItem.aggregate).toHaveBeenCalledTimes(1);
  });

  it('is a no-op (no lock, no query) when nothing in the order is capped', async () => {
    const tx = txWith(0);
    await expect(
      call(
        tx,
        [{ id: 'p1', name: 'Tart', dailyMaxQuantity: null }],
        new Map([['p1', 5]]),
        DAY,
      ),
    ).resolves.toBeUndefined();
    expect(tx.$executeRaw).not.toHaveBeenCalled();
    expect(tx.orderItem.aggregate).not.toHaveBeenCalled();
  });

  it('buckets by Vietnam date (UTC+7), not UTC — 18:30Z falls in the next VN day', async () => {
    const tx = txWith(0);
    // 2026-06-20T18:30Z = 2026-06-21 01:30 in Vietnam → VN day is June 21,
    // whose window is [2026-06-20T17:00Z, 2026-06-21T17:00Z). The old UTC-based
    // code would have bucketed this into June 20.
    await call(
      tx,
      [{ id: 'p1', name: 'Chiffon', dailyMaxQuantity: 10 }],
      new Map([['p1', 1]]),
      new Date('2026-06-20T18:30:00Z'),
    );
    const where = tx.orderItem.aggregate.mock.calls[0][0].where;
    expect(where.order.OR[0].scheduledFor.gte.toISOString()).toBe(
      '2026-06-20T17:00:00.000Z',
    );
    expect(where.order.OR[0].scheduledFor.lt.toISOString()).toBe(
      '2026-06-21T17:00:00.000Z',
    );
    // The lock key carries the VN calendar date, not the UTC one.
    expect(tx.$executeRaw.mock.calls[0][1]).toBe('daily:p1:2026-06-21');
  });

  it('takes per-product locks in sorted id order (deadlock-safe)', async () => {
    const tx = txWith(0);
    await call(
      tx,
      [
        { id: 'p3', name: 'C', dailyMaxQuantity: 10 },
        { id: 'p1', name: 'A', dailyMaxQuantity: 10 },
        { id: 'p2', name: 'B', dailyMaxQuantity: 10 },
      ],
      new Map([
        ['p1', 1],
        ['p2', 1],
        ['p3', 1],
      ]),
      DAY, // 2026-06-20 10:00 VN → dayKey 2026-06-20
    );
    const lockKeys = tx.$executeRaw.mock.calls.map((c: unknown[]) => c[1]);
    expect(lockKeys).toEqual([
      'daily:p1:2026-06-20',
      'daily:p2:2026-06-20',
      'daily:p3:2026-06-20',
    ]);
  });
});

/**
 * A combo is read BEFORE the order transaction (to expand it into lines +
 * compute bundleDiscount). assertBundlesUnchanged re-validates it inside the tx
 * under a per-combo advisory lock so a concurrent admin edit/deactivate can't
 * leave the order with stale lines. Invoked via the prototype with a mock tx.
 */
describe('OrdersService.assertBundlesUnchanged (combo re-validation in tx)', () => {
  const call = (tx: unknown, bundleById: Map<string, unknown>): Promise<void> =>
    (
      OrdersService.prototype as unknown as {
        assertBundlesUnchanged(
          t: unknown,
          b: Map<string, unknown>,
        ): Promise<void>;
      }
    ).assertBundlesUnchanged.call({}, tx, bundleById);

  const snapshot = {
    priceVnd: 100000,
    items: [
      { productId: 'p1', variantId: 'v1', quantity: 1 },
      { productId: 'p2', variantId: null, quantity: 2 },
    ],
  };
  function txReturning(fresh: unknown) {
    return {
      $executeRaw: jest.fn().mockResolvedValue(0),
      bundle: { findUnique: jest.fn().mockResolvedValue(fresh) },
    };
  }

  it('passes when the combo is unchanged (order-insensitive fingerprint)', async () => {
    const tx = txReturning({
      isActive: true,
      priceVnd: 100000,
      items: [
        { productId: 'p2', variantId: null, quantity: 2 }, // different order
        { productId: 'p1', variantId: 'v1', quantity: 1 },
      ],
    });
    await expect(
      call(tx, new Map([['b1', snapshot]])),
    ).resolves.toBeUndefined();
    // Took the per-combo advisory lock before reading.
    expect(tx.$executeRaw).toHaveBeenCalledTimes(1);
  });

  it('rejects a combo deactivated mid-checkout', async () => {
    const tx = txReturning({
      isActive: false,
      priceVnd: 100000,
      items: snapshot.items,
    });
    await expect(call(tx, new Map([['b1', snapshot]]))).rejects.toMatchObject({
      response: { code: 'BUNDLE_UNAVAILABLE' },
    });
  });

  it('rejects a combo whose price/composition changed mid-checkout', async () => {
    const tx = txReturning({
      isActive: true,
      priceVnd: 90000, // price changed
      items: snapshot.items,
    });
    await expect(call(tx, new Map([['b1', snapshot]]))).rejects.toMatchObject({
      response: { code: 'BUNDLE_CHANGED' },
    });
  });

  it('is a no-op when the cart has no combos', async () => {
    const tx = txReturning(null);
    await call(tx, new Map());
    expect(tx.$executeRaw).not.toHaveBeenCalled();
    expect(tx.bundle.findUnique).not.toHaveBeenCalled();
  });
});

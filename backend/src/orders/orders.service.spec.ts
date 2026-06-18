import { BadRequestException } from '@nestjs/common';

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

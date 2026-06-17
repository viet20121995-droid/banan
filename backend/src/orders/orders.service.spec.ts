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

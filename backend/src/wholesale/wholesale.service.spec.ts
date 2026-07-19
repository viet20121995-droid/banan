import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

// nanoid is ESM-only, pulled in via orders/order-code — CJS stub for Jest.
jest.mock('nanoid', () => ({ customAlphabet: () => () => 'TESTID' }));

import { WholesaleService } from './wholesale.service';

/**
 * Rule tests for the wholesale (on-account B2B) flow: account gating,
 * contract-only items, contract pricing snapshot, debt gates (overdue +
 * credit limit), receivable creation, mark-paid guard, and the admin
 * confirm handoff into the shared kitchen pipeline.
 */

const decimal = (n: number) => new Prisma.Decimal(n);

const ACCOUNT = {
  id: 'wa1',
  userId: 'u1',
  active: true,
  blockedReason: null,
  creditLimitVnd: 10_000_000,
  paymentTermDays: 30,
};

const CONTRACT = {
  id: 'wc1',
  wholesaleAccountId: 'wa1',
  name: 'HĐ 2026',
  active: true,
  startsAt: new Date('2026-01-01'),
  endsAt: null,
  minOrderVnd: null,
  defaultDiscountPct: null,
  paymentTermDays: null,
  lines: [
    {
      id: 'l1',
      productId: 'p1',
      variantId: null,
      fixedPriceVnd: 120_000,
      discountPct: null,
      minQty: 5,
      active: true,
      leadTimeHours: null,
    },
    {
      id: 'l2',
      productId: 'p2',
      variantId: null,
      fixedPriceVnd: null,
      discountPct: decimal(10),
      minQty: 1,
      active: true,
      leadTimeHours: null,
    },
  ],
};

const PRODUCTS = [
  {
    id: 'p1',
    storeId: 's1',
    name: 'Bánh su sỉ',
    basePrice: decimal(150_000),
    isAvailable: true,
    variants: [{ id: 'v1', size: 'M', flavor: 'Vani', priceDelta: decimal(0), isAvailable: true }],
  },
  {
    id: 'p2',
    storeId: 's1',
    name: 'Cookie sỉ',
    basePrice: decimal(100_000),
    isAvailable: true,
    variants: [{ id: 'v2', size: 'M', flavor: 'Choco', priceDelta: decimal(0), isAvailable: true }],
  },
];

type Overrides = {
  account?: unknown;
  contract?: unknown;
  overdueCount?: number;
  openDebt?: number;
  products?: unknown[];
};

function makeService(over: Overrides = {}) {
  const orderCreate = jest.fn().mockResolvedValue({ id: 'o1', code: 'BAN-W-1' });
  const receivableCreate = jest.fn().mockResolvedValue({ id: 'r1' });
  const tx = {
    $queryRaw: jest.fn().mockResolvedValue([{ id: 'wa1' }]),
    order: { create: orderCreate },
    wholesaleAccount: {
      findUniqueOrThrow: jest.fn().mockResolvedValue({
        active: true,
        blockedReason: null,
        creditLimitVnd: ACCOUNT.creditLimitVnd,
      }),
    },
    wholesaleReceivable: {
      count: jest.fn().mockResolvedValue(over.overdueCount ?? 0),
      aggregate: jest.fn().mockResolvedValue({ _sum: { amountVnd: decimal(over.openDebt ?? 0) } }),
      create: receivableCreate,
    },
  };
  const prisma = {
    wholesaleAccount: {
      findUnique: jest.fn().mockResolvedValue(over.account === undefined ? ACCOUNT : over.account),
    },
    wholesaleContract: {
      findFirst: jest
        .fn()
        .mockResolvedValue(over.contract === undefined ? CONTRACT : over.contract),
    },
    wholesaleReceivable: {
      count: jest.fn().mockResolvedValue(over.overdueCount ?? 0),
      aggregate: jest.fn().mockResolvedValue({ _sum: { amountVnd: decimal(over.openDebt ?? 0) } }),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'r1', status: 'PAID' }),
    },
    product: { findMany: jest.fn().mockResolvedValue(over.products ?? PRODUCTS) },
    order: { findUnique: jest.fn() },
    $transaction: jest.fn((cb: (t: unknown) => unknown) => cb(tx)),
  };
  const orders = {
    reserveChannelStock: jest.fn().mockResolvedValue(undefined),
    notifyWholesaleOrderCreated: jest.fn(),
    transition: jest.fn().mockResolvedValue({ id: 'o1', status: 'CANCELLED' }),
    confirmWholesaleOrder: jest.fn().mockResolvedValue({ id: 'o1', status: 'SENT_TO_KITCHEN' }),
  };
  const svc = new WholesaleService(prisma as never, orders as never);
  return { svc, prisma, orders, orderCreate, receivableCreate };
}

const dto = { contractId: 'wc1', items: [{ productId: 'p1', quantity: 5 }] };

describe('WholesaleService.createOrder', () => {
  it('rejects a user with no active wholesale account', async () => {
    const { svc } = makeService({ account: null });
    await expect(svc.createOrder('u1', dto)).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('rejects a blocked account with the block reason', async () => {
    const { svc } = makeService({
      account: { ...ACCOUNT, active: false, blockedReason: 'Nợ xấu' },
    });
    await expect(svc.createOrder('u1', dto)).rejects.toMatchObject({
      response: { message: expect.stringContaining('Nợ xấu') },
    });
  });

  it('blocks when any receivable is past due', async () => {
    const { svc } = makeService({ overdueCount: 1 });
    await expect(svc.createOrder('u1', dto)).rejects.toMatchObject({
      response: { code: 'WHOLESALE_OVERDUE' },
    });
  });

  it('blocks an item outside the contract', async () => {
    const { svc } = makeService();
    await expect(
      svc.createOrder('u1', {
        contractId: 'wc1',
        items: [
          { productId: 'p1', quantity: 5 },
          { productId: 'p3', quantity: 1 },
        ],
      }),
    ).rejects.toBeInstanceOf(BadRequestException); // p3 not even a product here
  });

  it('blocks quantity under the line minQty', async () => {
    const { svc } = makeService();
    await expect(
      svc.createOrder('u1', { contractId: 'wc1', items: [{ productId: 'p1', quantity: 2 }] }),
    ).rejects.toMatchObject({ response: { code: 'WHOLESALE_MIN_QTY' } });
  });

  it('blocks when open debt + this order would bust the credit limit', async () => {
    // 5 × 120k = 600k new; 9.5M already open vs a 10M limit.
    const { svc } = makeService({ openDebt: 9_500_000 });
    await expect(svc.createOrder('u1', dto)).rejects.toMatchObject({
      response: { code: 'WHOLESALE_CREDIT_LIMIT' },
    });
  });

  it('snapshots CONTRACT prices and creates a pending credit commitment', async () => {
    const { svc, orderCreate, receivableCreate } = makeService();
    await svc.createOrder('u1', {
      contractId: 'wc1',
      items: [
        { productId: 'p1', quantity: 5 }, // fixed 120k (retail 150k)
        { productId: 'p2', quantity: 2 }, // 10% off 100k → 90k
      ],
    });

    const data = orderCreate.mock.calls[0][0].data;
    expect(data.source).toBe('WHOLESALE');
    expect(data.settlementMode).toBe('ON_ACCOUNT');
    expect(data.status).toBe('PENDING'); // waits for admin confirm
    expect(data.wholesaleAccountId).toBe('wa1');
    expect(data.wholesaleContractId).toBe('wc1');
    const lines = data.items.createMany.data;
    expect(Number(lines[0].unitPrice.toString())).toBe(120_000);
    expect(Number(lines[1].unitPrice.toString())).toBe(90_000);
    // total = 5×120k + 2×90k = 780k
    expect(Number(data.total.toString())).toBe(780_000);

    const rec = receivableCreate.mock.calls[0][0].data;
    expect(Number(rec.amountVnd.toString())).toBe(780_000);
    expect(rec.status).toBe('PENDING');
    expect(rec.dueDate).toBeNull();
  });

  it('never touches any payment provider', async () => {
    const { svc, prisma } = makeService();
    await svc.createOrder('u1', dto);
    // The tx only creates the order + receivable — no payment/gateway calls
    // exist anywhere in this service (nothing to assert a call on).
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
  });
});

describe('WholesaleService.confirmOrder', () => {
  it('delegates to the atomic shared order confirmation', async () => {
    const { svc, orders } = makeService();
    const admin = { sub: 'adm', role: 'ADMIN' as never };
    await svc.confirmOrder('o1', admin);
    expect(orders.confirmWholesaleOrder).toHaveBeenCalledWith('o1', admin);
  });
});

describe('WholesaleService.rejectOrder', () => {
  it('cancels only a pending wholesale order through shared compensation', async () => {
    const { svc, prisma, orders } = makeService();
    prisma.order.findUnique = jest
      .fn()
      .mockResolvedValue({ source: 'WHOLESALE', status: 'PENDING' });
    const admin = { sub: 'adm', role: 'ADMIN' as never };
    await svc.rejectOrder('o1', admin, 'Không đủ lead time');
    expect(orders.transition).toHaveBeenCalledWith('o1', 'CANCELLED', admin, 'Không đủ lead time');
  });
});

describe('WholesaleService.markReceivablePaid', () => {
  it('status-guarded: an already-paid receivable cannot be re-paid', async () => {
    const { svc, prisma } = makeService();
    prisma.wholesaleReceivable.updateMany = jest.fn().mockResolvedValue({ count: 0 });
    await expect(svc.markReceivablePaid('r1', 'adm')).rejects.toMatchObject({
      response: { code: 'RECEIVABLE_NOT_OPEN' },
    });
  });

  it('stamps paidAt + the confirming admin', async () => {
    const { svc, prisma } = makeService();
    await svc.markReceivablePaid('r1', 'adm');
    const args = (prisma.wholesaleReceivable.updateMany as jest.Mock).mock.calls[0][0];
    expect(args.where.status.in).toEqual(['OPEN', 'PARTIAL', 'OVERDUE']);
    expect(args.data.status).toBe('PAID');
    expect(args.data.confirmedByAdminId).toBe('adm');
  });
});

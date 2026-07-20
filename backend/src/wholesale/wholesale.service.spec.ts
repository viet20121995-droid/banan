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
  receivable?: unknown;
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
      // recordReceivablePayment path (row-locked read → ledger → update).
      findUnique: jest.fn().mockImplementation(() => Promise.resolve(over.receivable ?? null)),
      update: jest.fn().mockResolvedValue({}),
      findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'r1', status: 'PAID' }),
    },
    wholesalePayment: {
      create: jest.fn().mockResolvedValue({ id: 'wp1' }),
      findUnique: jest.fn().mockResolvedValue(null),
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
  return { svc, prisma, tx, orders, orderCreate, receivableCreate };
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

describe('WholesaleService.recordReceivablePayment (ledger)', () => {
  const openReceivable = {
    id: 'r1',
    status: 'OPEN',
    amountVnd: decimal(1_000_000),
    paidAmountVnd: decimal(0),
  };

  it('an already-paid receivable cannot be re-paid', async () => {
    const { svc } = makeService({
      receivable: { ...openReceivable, status: 'PAID' },
    });
    await expect(svc.markReceivablePaid('r1', 'adm')).rejects.toMatchObject({
      response: { code: 'RECEIVABLE_NOT_OPEN' },
    });
  });

  it('a PARTIAL collection is recorded in the ledger and leaves the rest open', async () => {
    const { svc, tx } = makeService({ receivable: openReceivable });
    await svc.recordReceivablePayment('r1', 'adm', {
      amountVnd: 400_000,
      method: 'BANK_TRANSFER',
      reference: 'FT2607',
    });
    const ledger = (tx.wholesalePayment.create as jest.Mock).mock.calls[0][0].data;
    expect(Number(ledger.amountVnd.toString())).toBe(400_000);
    expect(ledger.method).toBe('BANK_TRANSFER');
    expect(ledger.reference).toBe('FT2607');
    expect(ledger.confirmedByAdminId).toBe('adm');
    const upd = (tx.wholesaleReceivable.update as jest.Mock).mock.calls[0][0].data;
    expect(upd.status).toBe('PARTIAL');
    expect(upd.paidAt).toBeUndefined();
  });

  it('collecting the full remaining balance flips PAID with paidAt + admin', async () => {
    const { svc, tx } = makeService({
      receivable: { ...openReceivable, status: 'PARTIAL', paidAmountVnd: decimal(400_000) },
    });
    await svc.markReceivablePaid('r1', 'adm'); // no amount = remaining 600k
    const ledger = (tx.wholesalePayment.create as jest.Mock).mock.calls[0][0].data;
    expect(Number(ledger.amountVnd.toString())).toBe(600_000);
    const upd = (tx.wholesaleReceivable.update as jest.Mock).mock.calls[0][0].data;
    expect(upd.status).toBe('PAID');
    expect(upd.paidAt).toBeInstanceOf(Date);
    expect(upd.confirmedByAdminId).toBe('adm');
  });

  it('rejects a collection above the remaining balance', async () => {
    const { svc } = makeService({ receivable: openReceivable });
    await expect(
      svc.recordReceivablePayment('r1', 'adm', { amountVnd: 1_200_000 }),
    ).rejects.toMatchObject({ response: { code: 'PAYMENT_AMOUNT_INVALID' } });
  });
});

describe('receivable payment idempotency + overdue preservation', () => {
  it('a retried confirm with the same key returns without a second ledger entry', async () => {
    const { svc, tx } = makeService({
      receivable: {
        id: 'r1',
        status: 'OPEN',
        amountVnd: decimal(1_000_000),
        paidAmountVnd: decimal(0),
      },
    });
    (tx.wholesalePayment.findUnique as jest.Mock).mockResolvedValue({ id: 'wp0' });
    await svc.recordReceivablePayment('r1', 'adm', {
      amountVnd: 400_000,
      clientRequestId: 'pay-12345678',
    });
    expect(tx.wholesalePayment.create).not.toHaveBeenCalled();
    expect(tx.wholesaleReceivable.update).not.toHaveBeenCalled();
  });

  it('a partial payment on a PAST-DUE receivable stays OVERDUE (not PARTIAL)', async () => {
    const { svc, tx } = makeService({
      receivable: {
        id: 'r1',
        status: 'OVERDUE',
        amountVnd: decimal(1_000_000),
        paidAmountVnd: decimal(0),
        dueDate: new Date(Date.now() - 86_400_000),
      },
    });
    await svc.recordReceivablePayment('r1', 'adm', { amountVnd: 400_000 });
    const upd = (tx.wholesaleReceivable.update as jest.Mock).mock.calls[0][0].data;
    expect(upd.status).toBe('OVERDUE');
  });
});

describe('wholesale order idempotency', () => {
  it('replays the SAME order for a duplicate clientRequestId (no second create)', async () => {
    const existing = { id: 'first', code: 'BAN-W-0' };
    const { svc, prisma, orderCreate } = makeService();
    prisma.order.findUnique = jest.fn().mockResolvedValue(existing);
    const res = await svc.createOrder('u1', { ...dto, clientRequestId: 'wh-12345678' });
    expect(res).toBe(existing);
    expect(orderCreate).not.toHaveBeenCalled();
  });
});

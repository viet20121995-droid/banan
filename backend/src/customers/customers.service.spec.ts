import { ForbiddenException } from '@nestjs/common';

import { CustomersService } from './customers.service';

/**
 * Guards the merchant CRM "edit profile" identity boundary: a store-scoped
 * merchant/staff must not change a CLAIMED customer's email/phone (that would
 * enable password-reset takeover). Admin and unclaimed stubs may.
 */

type UserRow = {
  id: string;
  email: string;
  phone: string | null;
  claimed: boolean;
  role: string;
  addresses: unknown[];
};

function makeService(user: UserRow, opts: { servedOrders?: number } = {}) {
  const update = jest.fn().mockResolvedValue({
    id: user.id,
    fullName: 'X',
    email: user.email,
    phone: user.phone,
    birthday: null,
  });
  const prisma = {
    user: {
      findFirst: jest.fn().mockResolvedValue(user),
      update,
    },
    order: {
      // loadServed requires ≥1 served order when a storeId is supplied.
      findMany: jest.fn().mockResolvedValue(
        Array.from({ length: opts.servedOrders ?? 1 }, (_, i) => ({
          id: `o${i}`,
          code: 'BAN-1',
          status: 'COMPLETED',
          fulfillmentType: 'PICKUP',
          total: 1000,
          createdAt: new Date(),
          store: { id: 's1', name: 'S' },
        })),
      ),
    },
  };
  const noop = {} as never;
  const svc = new CustomersService(prisma as never, noop, noop);
  return { svc, update };
}

const baseUser = (over: Partial<UserRow> = {}): UserRow => ({
  id: 'u1',
  email: 'old@x.com',
  phone: '0900000000',
  claimed: true,
  role: 'CUSTOMER',
  addresses: [],
  ...over,
});

describe('CustomersService.updateProfile (identity boundary)', () => {
  it('merchant CANNOT change a claimed customer email', async () => {
    const { svc, update } = makeService(baseUser({ claimed: true }));
    await expect(
      svc.updateProfile('s1', 'u1', { email: 'attacker@evil.com' }),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(update).not.toHaveBeenCalled();
  });

  it('merchant CANNOT change a claimed customer phone', async () => {
    const { svc, update } = makeService(baseUser({ claimed: true }));
    await expect(svc.updateProfile('s1', 'u1', { phone: '0911111111' })).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(update).not.toHaveBeenCalled();
  });

  it('merchant CAN change an UNCLAIMED stub email', async () => {
    const { svc, update } = makeService(baseUser({ claimed: false }));
    await svc.updateProfile('s1', 'u1', { email: 'new@x.com' });
    expect(update).toHaveBeenCalledTimes(1);
    expect(update.mock.calls[0][0].data.email).toBe('new@x.com');
  });

  it('admin CAN change a claimed customer email (storeId null)', async () => {
    const { svc, update } = makeService(baseUser({ claimed: true }), {
      servedOrders: 0, // admin path doesn't require served orders
    });
    await svc.updateProfile(null, 'u1', { email: 'admin-set@x.com' });
    expect(update).toHaveBeenCalledTimes(1);
    expect(update.mock.calls[0][0].data.email).toBe('admin-set@x.com');
  });

  it('merchant CAN edit non-identity fields (fullName) on a claimed customer', async () => {
    const { svc, update } = makeService(baseUser({ claimed: true }));
    await svc.updateProfile('s1', 'u1', { fullName: 'Tên Mới' });
    expect(update).toHaveBeenCalledTimes(1);
    expect(update.mock.calls[0][0].data.fullName).toBe('Tên Mới');
    expect(update.mock.calls[0][0].data.email).toBeUndefined();
  });
});

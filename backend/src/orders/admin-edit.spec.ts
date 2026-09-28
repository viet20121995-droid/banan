jest.mock('nanoid', () => ({ customAlphabet: () => () => 'test-id' }));

import { OrdersService } from './orders.service';

/** Admin hand-fix of an order: a shared saved address is copied, not edited. */
function setup(sharedCount: number) {
  const addr = {
    id: 'a1',
    userId: 'u1',
    label: 'Home',
    recipient: 'Hoa',
    phone: '0900000000',
    line1: '1 Old St',
    line2: null,
    city: 'HCM',
    district: null,
    wardCode: 'ben-thanh',
    postalCode: null,
    lat: 1,
    lng: 2,
    isDefault: true,
  };
  const prisma = {
    order: {
      findUnique: jest.fn().mockResolvedValue({
        id: 'o1',
        status: 'PENDING',
        scheduledFor: null,
        customerId: 'u1',
        customer: { id: 'u1', fullName: 'A', role: 'CUSTOMER' },
        address: addr,
      }),
      count: jest.fn().mockResolvedValue(sharedCount),
      update: jest.fn().mockResolvedValue({ id: 'o1', storeId: 's1', customerId: 'u1' }),
    },
    address: {
      create: jest.fn().mockResolvedValue({ id: 'a2' }),
      update: jest.fn(),
    },
    user: { update: jest.fn() },
  };
  const noop = {} as never;
  const svc = new OrdersService(
    prisma as never,
    { emit: jest.fn() } as never,
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
  (svc as unknown as { toEventPayload: () => object }).toEventPayload = () => ({});
  return { svc, prisma };
}

describe('OrdersService.adminEdit address', () => {
  it('edits in place when only this order uses the address', async () => {
    const { svc, prisma } = setup(1);
    await svc.adminEdit('o1', 'admin', { addressLine: '2 New St', recipient: 'Hoa' });
    expect(prisma.address.update).toHaveBeenCalledWith({
      where: { id: 'a1' },
      data: { line1: '2 New St' },
    });
    expect(prisma.address.create).not.toHaveBeenCalled();
    const data = prisma.order.update.mock.calls[0][0].data;
    expect(data.statusEvents.create.note).toContain('"1 Old St" → "2 New St"');
    expect(data.statusEvents.create.note).not.toContain('người nhận');
  });

  it('copies a shared address so other orders keep theirs', async () => {
    const { svc, prisma } = setup(3);
    await svc.adminEdit('o1', 'admin', { recipient: 'Khanh Hoa' });
    expect(prisma.address.update).not.toHaveBeenCalled();
    const created = prisma.address.create.mock.calls[0][0].data;
    expect(created).toMatchObject({ recipient: 'Khanh Hoa', line1: '1 Old St', isDefault: false });
    expect(created.id).toBeUndefined();
    expect(prisma.order.update.mock.calls[0][0].data.address).toEqual({ connect: { id: 'a2' } });
  });
});

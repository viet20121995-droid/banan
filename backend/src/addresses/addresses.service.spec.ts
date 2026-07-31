import { BadRequestException } from '@nestjs/common';

import { AddressesService } from './addresses.service';
import type { CreateAddressDto } from './dto/address.dto';

/**
 * The address book is the main writer of Address.wardCode — it must only
 * ever persist codes the geo catalog can resolve, canonicalized, and must
 * refuse split-ward legacy codes instead of guessing.
 */

function makeService() {
  const create = jest.fn(async (args: { data: Record<string, unknown> }) => ({
    id: 'a1',
    ...args.data,
  }));
  const update = jest.fn(async (args: { data: Record<string, unknown> }) => ({
    id: 'a1',
    userId: 'u1',
    ...args.data,
  }));
  const tx = {
    address: {
      create,
      update,
      updateMany: jest.fn().mockResolvedValue({ count: 0 }),
    },
  };
  const prisma = {
    address: {
      count: jest.fn().mockResolvedValue(1),
      findUnique: jest.fn().mockResolvedValue({ id: 'a1', userId: 'u1', isDefault: false }),
    },
    $transaction: jest.fn(async (fn: (t: typeof tx) => Promise<unknown>) => fn(tx)),
  };
  const service = new AddressesService(prisma as never);
  return { service, create, update };
}

const baseDto: CreateAddressDto = {
  label: 'Nhà',
  recipient: 'Nguyễn Văn A',
  phone: '0901234567',
  line1: '12 Lê Lợi',
  city: 'Thành phố Hồ Chí Minh',
} as CreateAddressDto;

describe('AddressesService wardCode validation', () => {
  it('stores a canonical code as-is', async () => {
    const { service, create } = makeService();
    await service.create('u1', { ...baseDto, wardCode: 'sai-gon' });
    expect(create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ wardCode: 'sai-gon' }),
      }),
    );
  });

  it('canonicalizes a safe (whole-merge) legacy alias on save', async () => {
    const { service, create } = makeService();
    await service.create('u1', { ...baseDto, wardCode: 'cau-kho' });
    expect(create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ wardCode: 'cau-ong-lanh' }),
      }),
    );
  });

  it('keeps an omitted/empty wardCode as null', async () => {
    const { service, create } = makeService();
    await service.create('u1', { ...baseDto, wardCode: '  ' });
    expect(create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ wardCode: null }),
      }),
    );
  });

  it('rejects an unknown code with WARD_NOT_FOUND', async () => {
    const { service } = makeService();
    await expect(
      service.create('u1', { ...baseDto, wardCode: 'khong-ton-tai' }),
    ).rejects.toMatchObject({
      constructor: BadRequestException,
      response: expect.objectContaining({ code: 'WARD_NOT_FOUND' }),
    });
  });

  it('refuses a split-ward legacy code with WARD_RESELECTION_REQUIRED', async () => {
    const { service } = makeService();
    for (const code of ['da-kao', 'an-phu', 'phu-my']) {
      await expect(service.create('u1', { ...baseDto, wardCode: code })).rejects.toMatchObject({
        response: expect.objectContaining({ code: 'WARD_RESELECTION_REQUIRED' }),
      });
    }
  });

  it('applies the same rules on update', async () => {
    const { service, update } = makeService();
    await service.update('u1', 'a1', { wardCode: 'thao-dien' });
    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ wardCode: 'an-khanh' }),
      }),
    );
    await expect(service.update('u1', 'a1', { wardCode: 'an-phu' })).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'WARD_RESELECTION_REQUIRED' }),
    });
  });
});

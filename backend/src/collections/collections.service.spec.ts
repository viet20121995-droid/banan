import { BadRequestException, ForbiddenException } from '@nestjs/common';

import type { PrismaService } from '../prisma/prisma.service';

import { CollectionsService } from './collections.service';

/**
 * Unit tests for the `addItems` append flow (the "add to collection" path used
 * by the merchant menu multi-select). Prisma is hand-mocked; the collection is
 * returned with `items: []` so the birthday-cake decorator short-circuits
 * (empty id list → no extra queries) and the test stays focused on the append
 * semantics: scope check, existence check, idempotent skip, sortOrder bump.
 */
describe('CollectionsService.addItems', () => {
  let prisma: {
    collection: { findUnique: jest.Mock; findUniqueOrThrow: jest.Mock };
    collectionItem: { findMany: jest.Mock; createMany: jest.Mock };
    product: { count: jest.Mock };
    deliveryConfig: { findUnique: jest.Mock };
    $transaction: jest.Mock;
  };
  let service: CollectionsService;

  beforeEach(() => {
    prisma = {
      collection: {
        findUnique: jest.fn(),
        findUniqueOrThrow: jest.fn(),
      },
      collectionItem: {
        findMany: jest.fn(),
        createMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      product: { count: jest.fn() },
      deliveryConfig: { findUnique: jest.fn().mockResolvedValue(null) },
      // Interactive transaction — run the callback against the same mock.
      $transaction: jest.fn((cb: (tx: unknown) => unknown) => cb(prisma)),
    };
    service = new CollectionsService(prisma as unknown as PrismaService);
  });

  it('skips products already in the collection and appends the rest after the max sortOrder', async () => {
    prisma.collection.findUnique.mockResolvedValue({
      id: 'c1',
      storeId: 's1',
      items: [],
    });
    prisma.product.count.mockResolvedValue(3); // p1, p2, p3 all exist
    prisma.collectionItem.findMany.mockResolvedValue([
      { productId: 'p1', sortOrder: 0 },
    ]);
    prisma.collection.findUniqueOrThrow.mockResolvedValue({
      id: 'c1',
      items: [],
    });

    await service.addItems('c1', 's1', ['p1', 'p2', 'p3']);

    // p1 already present → skipped; p2/p3 appended at 1 and 2 in one
    // race-safe createMany (skipDuplicates).
    expect(prisma.collectionItem.createMany).toHaveBeenCalledTimes(1);
    expect(prisma.collectionItem.createMany).toHaveBeenCalledWith({
      data: [
        { collectionId: 'c1', productId: 'p2', sortOrder: 1 },
        { collectionId: 'c1', productId: 'p3', sortOrder: 2 },
      ],
      skipDuplicates: true,
    });
  });

  it('de-duplicates the incoming product ids', async () => {
    prisma.collection.findUnique.mockResolvedValue({
      id: 'c1',
      storeId: 's1',
      items: [],
    });
    prisma.product.count.mockResolvedValue(1); // single distinct id
    prisma.collectionItem.findMany.mockResolvedValue([]);
    prisma.collection.findUniqueOrThrow.mockResolvedValue({
      id: 'c1',
      items: [],
    });

    await service.addItems('c1', 's1', ['p9', 'p9', 'p9']);

    expect(prisma.product.count).toHaveBeenCalledWith({
      where: { id: { in: ['p9'] } },
    });
    expect(prisma.collectionItem.createMany).toHaveBeenCalledWith({
      data: [{ collectionId: 'c1', productId: 'p9', sortOrder: 0 }],
      skipDuplicates: true,
    });
  });

  it('rejects when the collection belongs to another store', async () => {
    prisma.collection.findUnique.mockResolvedValue({
      id: 'c1',
      storeId: 's1',
      items: [],
    });

    await expect(
      service.addItems('c1', 's2', ['p1']),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('rejects when a referenced product no longer exists', async () => {
    prisma.collection.findUnique.mockResolvedValue({
      id: 'c1',
      storeId: 's1',
      items: [],
    });
    prisma.product.count.mockResolvedValue(1); // only 1 of 2 ids found

    await expect(
      service.addItems('c1', 's1', ['p1', 'gone']),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('is a no-op (no transaction) when given an empty list', async () => {
    prisma.collection.findUnique.mockResolvedValue({
      id: 'c1',
      storeId: 's1',
      items: [],
    });

    await service.addItems('c1', 's1', []);

    expect(prisma.product.count).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
});

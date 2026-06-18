import { BadRequestException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

/**
 * Resolves the chain-wide catalog store id — the store that owns catalog
 * content (products, collections, bundles, threads). Prefers the seeded
 * primary branch (slug `banan-le-thanh-ton`), else the oldest store.
 *
 * Admin accounts have no `storeId`, so admin-created catalog content attaches
 * here. Mirrors `ProductsService.catalogStoreId` (products already do this);
 * shared so collections/bundles/threads stay consistent.
 */
export async function resolveCatalogStoreId(
  prisma: PrismaService,
): Promise<string> {
  const primary = await prisma.store.findUnique({
    where: { slug: 'banan-le-thanh-ton' },
    select: { id: true },
  });
  if (primary) return primary.id;
  const anyStore = await prisma.store.findFirst({
    orderBy: { createdAt: 'asc' },
    select: { id: true },
  });
  if (!anyStore) {
    throw new BadRequestException({
      code: 'NO_STORES',
      message: 'No store exists — cannot resolve catalog owner.',
    });
  }
  return anyStore.id;
}

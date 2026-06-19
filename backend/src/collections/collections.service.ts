import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import type { AuthPrincipal } from '../auth/types/jwt-payload';
import { resolveCatalogStoreId } from '../common/catalog-store';
import { PrismaService } from '../prisma/prisma.service';
import { birthdayCakeProductIds } from '../products/birthday-cake.util';

import type {
  CollectionItemInputDto,
  CreateCollectionDto,
  UpdateCollectionDto,
} from './dto/collection.dto';

// Merchant/admin view — every item, even unavailable ones, so staff can
// curate. `createdAt` is a deterministic tiebreaker so two items sharing a
// sortOrder don't reorder between identical reads.
const COLLECTION_INCLUDE = {
  items: {
    include: {
      product: {
        include: {
          variants: { orderBy: [{ size: 'asc' }, { flavor: 'asc' }] },
          category: true,
        },
      },
    },
    orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
  },
} satisfies Prisma.CollectionInclude;

// Customer-facing view — hide items whose product is unavailable so the home
// strip / collection page never shows a cake that checkout would reject with
// PRODUCT_UNAVAILABLE (and never fires the quick-add wizard on an unorderable
// product).
const PUBLIC_COLLECTION_INCLUDE = {
  items: {
    where: { product: { isAvailable: true } },
    include: {
      product: {
        include: {
          variants: { orderBy: [{ size: 'asc' }, { flavor: 'asc' }] },
          category: true,
        },
      },
    },
    orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
  },
} satisfies Prisma.CollectionInclude;

@Injectable()
export class CollectionsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Chain-wide catalog store — where an admin-created collection attaches
   *  (admin has no branch storeId). */
  catalogStoreId(): Promise<string> {
    return resolveCatalogStoreId(this.prisma);
  }

  /** Public read — pinned + active collections shown on customer home.
   *  `_storeId` is accepted for API compatibility but intentionally ignored:
   *  collections are chain-wide (all on the catalog store), so filtering by a
   *  branch storeId would match nothing and silently empty the home feed. */
  async listForHome(_storeId?: string) {
    const collections = await this.prisma.collection.findMany({
      where: {
        isActive: true,
        isPinnedToHome: true,
        // Items must be present and the product still available.
        items: { some: { product: { isAvailable: true } } },
      },
      include: PUBLIC_COLLECTION_INCLUDE,
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
    return this.applyBirthdayFlag(collections);
  }

  /// Mutates every nested product with the `isBirthdayCake` flag (one
  /// membership query across all the given collections) so the customer
  /// cake-personalization wizard fires from home strips and collection
  /// pages too — matching the menu grid's quick-add behaviour.
  private async applyBirthdayFlag<
    C extends { items: Array<{ product: { id: string } }> },
  >(collections: C[]): Promise<C[]> {
    const ids: string[] = [];
    for (const c of collections) {
      for (const it of c.items) ids.push(it.product.id);
    }
    const birthdayIds = await birthdayCakeProductIds(this.prisma, ids);
    for (const c of collections) {
      for (const it of c.items) {
        (it.product as Record<string, unknown>).isBirthdayCake =
          birthdayIds.has(it.product.id);
      }
    }
    return collections;
  }

  /** Merchant-side list — every collection for the store. */
  /** Merchant list. `storeId` null = admin → every store's collections. */
  async listForStore(storeId: string | null) {
    return this.prisma.collection.findMany({
      where: storeId === null ? {} : { storeId },
      include: COLLECTION_INCLUDE,
      orderBy: [{ isPinnedToHome: 'desc' }, { sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
  }

  async findOne(id: string, storeIdScope: string | null) {
    const collection = await this.prisma.collection.findUnique({
      where: { id },
      include: COLLECTION_INCLUDE,
    });
    if (!collection) {
      throw new NotFoundException({ code: 'COLLECTION_NOT_FOUND' });
    }
    if (storeIdScope && collection.storeId !== storeIdScope) {
      throw new ForbiddenException({ code: 'AUTH_FORBIDDEN' });
    }
    const [decorated] = await this.applyBirthdayFlag([collection]);
    return decorated;
  }

  /** Public by-id. An active collection is visible to anyone; a deactivated
   *  one is returned only to an admin or the owning store's staff. The @Public
   *  route is optional-auth, so the merchant editor (which loads inactive
   *  collections by id with its token) works, while the public can't reach a
   *  deactivated collection by id. */
  async findOnePublic(id: string, viewer?: AuthPrincipal) {
    const collection = await this.prisma.collection.findUnique({
      where: { id },
      include: COLLECTION_INCLUDE,
    });
    if (!collection) {
      throw new NotFoundException({ code: 'COLLECTION_NOT_FOUND' });
    }
    // Privileged = admin or ANY merchant staff, who load the full item set for
    // the editor (incl. inactive collections + unavailable products).
    // Collections are chain-wide catalog content owned by the single catalog
    // store, so we do NOT gate on viewer.storeId — that would lock out every
    // branch merchant (whose storeId never equals the catalog store) and
    // contradict the read-for-all-staff model.
    const privileged =
      !!viewer &&
      (viewer.role === 'ADMIN' ||
        viewer.role === 'MERCHANT_OWNER' ||
        viewer.role === 'MERCHANT_STAFF');
    if (!collection.isActive && !privileged) {
      throw new NotFoundException({ code: 'COLLECTION_NOT_FOUND' });
    }
    // Customers never see a cake the storefront can't sell (checkout would
    // reject it with PRODUCT_UNAVAILABLE); privileged staff keep the full set.
    if (!privileged) {
      collection.items = collection.items.filter((it) => it.product.isAvailable);
    }
    const [decorated] = await this.applyBirthdayFlag([collection]);
    return decorated;
  }

  /** Maps Prisma write errors to clean 4xx instead of an opaque 500:
   *  - P2002 (unique slug) → 409. All collections share the catalog store, so
   *    @@unique([storeId, slug]) behaves as a global slug-uniqueness rule.
   *  - P2003 (FK violation) → 400 PRODUCT_NOT_FOUND. assertProductsExist runs
   *    before the tx, so a product deleted in the window makes the insert fail
   *    the Product FK; surface it as the same 400 the pre-check would have. */
  private rethrowCatalogWriteError(e: unknown): never {
    if (e instanceof Prisma.PrismaClientKnownRequestError) {
      if (e.code === 'P2002') {
        throw new ConflictException({
          code: 'COLLECTION_SLUG_TAKEN',
          message: 'Slug bộ sưu tập đã tồn tại — vui lòng chọn slug khác.',
        });
      }
      if (e.code === 'P2003') {
        throw new BadRequestException({
          code: 'PRODUCT_NOT_FOUND',
          message: 'Một hoặc nhiều sản phẩm không còn tồn tại.',
        });
      }
    }
    throw e;
  }

  async create(storeId: string, dto: CreateCollectionDto) {
    if (dto.items) await this.assertProductsExist(dto.items);
    try {
      return await this.prisma.collection.create({
        data: {
          storeId,
          name: dto.name,
          slug: dto.slug,
          description: dto.description,
          imageUrl: dto.imageUrl,
          isPinnedToHome: dto.isPinnedToHome ?? false,
          sortOrder: dto.sortOrder ?? 0,
          isActive: dto.isActive ?? true,
          items: dto.items
            ? {
                create: dto.items.map((it, idx) => ({
                  productId: it.productId,
                  sortOrder: it.sortOrder ?? idx,
                })),
              }
            : undefined,
        },
        include: COLLECTION_INCLUDE,
      });
    } catch (e) {
      this.rethrowCatalogWriteError(e);
    }
  }

  async update(id: string, storeIdScope: string | null, dto: UpdateCollectionDto) {
    await this.findOne(id, storeIdScope);
    if (dto.items) {
      await this.assertProductsExist(dto.items);
    }

    try {
      return await this.prisma.$transaction(async (tx) => {
        // Serialise against concurrent addItems()/update() on the same
        // collection (addItems takes the same lock) so a "replace" and an
        // "append" can't interleave and corrupt the item set / sortOrder.
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${id}, 0))`;
        await tx.collection.update({
          where: { id },
          data: {
            ...(dto.name !== undefined && { name: dto.name }),
            ...(dto.slug !== undefined && { slug: dto.slug }),
            ...(dto.description !== undefined && {
              description: dto.description,
            }),
            ...(dto.imageUrl !== undefined && { imageUrl: dto.imageUrl }),
            ...(dto.isPinnedToHome !== undefined && {
              isPinnedToHome: dto.isPinnedToHome,
            }),
            ...(dto.sortOrder !== undefined && { sortOrder: dto.sortOrder }),
            ...(dto.isActive !== undefined && { isActive: dto.isActive }),
          },
        });

        if (dto.items) {
          // Diff-update: items array is the new authoritative set.
          const incomingProductIds = dto.items.map((i) => i.productId);
          await tx.collectionItem.deleteMany({
            where: {
              collectionId: id,
              productId: {
                notIn:
                  incomingProductIds.length > 0
                    ? incomingProductIds
                    : ['__none__'],
              },
            },
          });
          for (let i = 0; i < dto.items.length; i++) {
            const it = dto.items[i];
            await tx.collectionItem.upsert({
              where: {
                collectionId_productId: {
                  collectionId: id,
                  productId: it.productId,
                },
              },
              create: {
                collectionId: id,
                productId: it.productId,
                sortOrder: it.sortOrder ?? i,
              },
              update: { sortOrder: it.sortOrder ?? i },
            });
          }
        }

        return tx.collection.findUniqueOrThrow({
          where: { id },
          include: COLLECTION_INCLUDE,
        });
      });
    } catch (e) {
      this.rethrowCatalogWriteError(e);
    }
  }

  /** Appends products to a collection — used by the "add to collection" flow
   *  from the menu list. Idempotent: products already in the collection are
   *  skipped; new ones go after the current max sortOrder. Scope-checked via
   *  findOne so a merchant can only add to their own store's collection. */
  async addItems(
    id: string,
    storeIdScope: string | null,
    productIds: string[],
  ) {
    await this.findOne(id, storeIdScope);
    const ids = [...new Set(productIds)];
    if (ids.length === 0) return this.findOne(id, storeIdScope);
    await this.assertProductsExist(ids.map((productId) => ({ productId })));

    try {
      return await this.prisma.$transaction(async (tx) => {
        // Serialize concurrent appends to THIS collection so two requests adding
        // different products can't both read the same max sortOrder and assign a
        // duplicate (which would make ordering non-deterministic). The lock is
        // released at transaction end.
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${id}, 0))`;
        const existing = await tx.collectionItem.findMany({
          where: { collectionId: id },
          select: { productId: true, sortOrder: true },
        });
        const have = new Set(existing.map((e) => e.productId));
        let next = existing.reduce((m, e) => Math.max(m, e.sortOrder), -1) + 1;
        const toAdd = ids
          .filter((productId) => !have.has(productId))
          .map((productId) => ({ collectionId: id, productId, sortOrder: next++ }));
        // createMany + skipDuplicates is idempotent and race-safe: two concurrent
        // "add this product" calls can't both pass the in-memory `have` check and
        // then collide on the (collectionId, productId) unique index — the loser's
        // row is silently skipped instead of throwing P2002.
        if (toAdd.length > 0) {
          await tx.collectionItem.createMany({
            data: toAdd,
            skipDuplicates: true,
          });
        }
        return tx.collection.findUniqueOrThrow({
          where: { id },
          include: COLLECTION_INCLUDE,
        });
      });
    } catch (e) {
      this.rethrowCatalogWriteError(e);
    }
  }

  async remove(id: string, storeIdScope: string | null): Promise<void> {
    await this.findOne(id, storeIdScope);
    await this.prisma.collection.delete({ where: { id } });
  }

  /// Products are a single chain-wide catalog (all owned by the catalog
  /// store), so ANY collection — at any branch — may curate ANY catalog
  /// product. We therefore only verify the referenced products still exist,
  /// not that they share the collection's store (the old same-store check
  /// rejected every product for non-catalog-store merchants).
  private async assertProductsExist(items: CollectionItemInputDto[]) {
    if (items.length === 0) return;
    const ids = [...new Set(items.map((i) => i.productId))];
    const found = await this.prisma.product.count({
      where: { id: { in: ids } },
    });
    if (found !== ids.length) {
      throw new BadRequestException({
        code: 'PRODUCT_NOT_FOUND',
        message: 'One or more products no longer exist.',
      });
    }
  }
}

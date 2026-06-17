import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import { birthdayCakeProductIds } from './birthday-cake.util';
import type { CreateProductDto } from './dto/create-product.dto';
import type { ListProductsDto } from './dto/list-products.dto';
import type { UpdateProductDto } from './dto/update-product.dto';
import type { VariantInputDto } from './dto/variant.dto';

const PRODUCT_INCLUDE = {
  variants: { orderBy: [{ size: 'asc' }, { flavor: 'asc' }] },
  category: true,
} satisfies Prisma.ProductInclude;

@Injectable()
export class ProductsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * The "catalog owner" — the single store whose products represent the
   * chain's shared menu. Every merchant CRUD operation funnels through
   * this store so all branches share one menu. Looked up by the slug of
   * the original Banan branch; cached after first hit.
   *
   * Order routing (which branch fulfills) is independent of the catalog
   * (`Order.storeId` is set per-pickup-choice). This only governs which
   * Product rows exist.
   */
  private catalogStoreIdCache: string | null = null;
  async catalogStoreId(): Promise<string> {
    if (this.catalogStoreIdCache) return this.catalogStoreIdCache;
    // Prefer the seeded primary branch; otherwise fall back to whichever
    // store has products today (helps in dev where seed may differ).
    const primary = await this.prisma.store.findUnique({
      where: { slug: 'banan-le-thanh-ton' },
      select: { id: true },
    });
    if (primary) {
      this.catalogStoreIdCache = primary.id;
      return primary.id;
    }
    const anyStore = await this.prisma.store.findFirst({
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (!anyStore) {
      throw new BadRequestException({
        code: 'NO_STORES',
        message: 'No store exists — cannot resolve catalog owner.',
      });
    }
    this.catalogStoreIdCache = anyStore.id;
    return anyStore.id;
  }

  async findAll(filters: ListProductsDto) {
    const page = filters.page ?? 1;
    const perPage = filters.perPage ?? 20;

    const where: Prisma.ProductWhereInput = {
      isAvailable: true,
      ...(filters.categoryId && { categoryId: filters.categoryId }),
      ...(filters.storeId && { storeId: filters.storeId }),
      ...(filters.seasonal !== undefined && {
        isSeasonal: filters.seasonal === 'true',
      }),
      ...(filters.q && {
        OR: [
          { name: { contains: filters.q, mode: 'insensitive' } },
          { description: { contains: filters.q, mode: 'insensitive' } },
          { tags: { has: filters.q } },
        ],
      }),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.product.findMany({
        where,
        include: PRODUCT_INCLUDE,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * perPage,
        take: perPage,
      }),
      this.prisma.product.count({ where }),
    ]);

    // Decorate with review summary (avg rating + count) and the
    // birthday-cake flag (drives the customer cake wizard on quick-add).
    const ids = items.map((p) => p.id);
    const summaries = await this.reviewSummariesForProducts(ids);
    const birthdayIds = await birthdayCakeProductIds(this.prisma, ids);
    const decorated = items.map((p) => ({
      ...p,
      averageRating: summaries[p.id]?.averageRating ?? 0,
      reviewCount: summaries[p.id]?.reviewCount ?? 0,
      isBirthdayCake: birthdayIds.has(p.id),
    }));

    return { items: decorated, meta: { page, perPage, total } };
  }

  /** Used by merchant dashboard — includes unavailable products. */
  async findAllForStore(storeId: string, filters: ListProductsDto) {
    const page = filters.page ?? 1;
    const perPage = filters.perPage ?? 20;

    const where: Prisma.ProductWhereInput = {
      storeId,
      ...(filters.categoryId && { categoryId: filters.categoryId }),
      ...(filters.q && {
        OR: [
          { name: { contains: filters.q, mode: 'insensitive' } },
          { description: { contains: filters.q, mode: 'insensitive' } },
          { tags: { has: filters.q } },
        ],
      }),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.product.findMany({
        where,
        include: PRODUCT_INCLUDE,
        orderBy: { updatedAt: 'desc' },
        skip: (page - 1) * perPage,
        take: perPage,
      }),
      this.prisma.product.count({ where }),
    ]);

    return { items, meta: { page, perPage, total } };
  }

  // Public product detail. Only an available (non-archived) product is
  // served — `remove()` archives sold-out/discontinued SKUs by setting
  // isAvailable=false and `findAll` hides them, so the by-id path must hide
  // them too (otherwise a stale deep-link exposes a discontinued item and can
  // re-add it to a cart). Merchant editing uses the merchant list + restore.
  async findOne(id: string) {
    const product = await this.prisma.product.findFirst({
      where: { id, isAvailable: true },
      include: PRODUCT_INCLUDE,
    });
    if (!product) throw new NotFoundException({ code: 'PRODUCT_NOT_FOUND' });
    const summaries = await this.reviewSummariesForProducts([product.id]);
    const isBirthdayCake = await this.isInBirthdayCollection(product.id);
    return {
      ...product,
      averageRating: summaries[product.id]?.averageRating ?? 0,
      reviewCount: summaries[product.id]?.reviewCount ?? 0,
      isBirthdayCake,
    };
  }

  /// True when the product belongs to the chain's "birthday cakes"
  /// collection (slug stored on `DeliveryConfig` — same definition used
  /// for the delivery-fee tier). Drives the cake personalization wizard
  /// on the customer product detail.
  private async isInBirthdayCollection(productId: string): Promise<boolean> {
    const ids = await birthdayCakeProductIds(this.prisma, [productId]);
    return ids.has(productId);
  }

  /// "Khách cũng mua" recommendations for a product.
  ///
  /// Approach (cheap and works without an ML stack): scan the last
  /// 5K orders that include the source product, count which OTHER
  /// products appeared in those baskets, return the top N. Fast and
  /// accurate enough for a single-store chain. When sales are too thin
  /// (cold start) we fall back to same-category siblings so the section
  /// never shows up empty.
  async recommendations(productId: string, limit = 8) {
    const src = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { id: true, categoryId: true, isAvailable: true },
    });
    if (!src) {
      throw new NotFoundException({ code: 'PRODUCT_NOT_FOUND' });
    }

    // Step 1 — co-occurrence in past baskets.
    const sourceLines = await this.prisma.orderItem.findMany({
      where: { productId },
      select: { orderId: true },
      take: 5000,
      orderBy: { id: 'desc' },
    });
    const orderIds = Array.from(new Set(sourceLines.map((l) => l.orderId)));

    const counts = new Map<string, number>();
    if (orderIds.length > 0) {
      const sibling = await this.prisma.orderItem.findMany({
        where: {
          orderId: { in: orderIds },
          productId: { not: productId },
        },
        select: { productId: true, quantity: true },
      });
      for (const s of sibling) {
        counts.set(s.productId, (counts.get(s.productId) ?? 0) + s.quantity);
      }
    }

    let topIds = Array.from(counts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, limit)
      .map(([id]) => id);

    // Step 2 — fallback: same-category siblings.
    if (topIds.length < limit) {
      const fillers = await this.prisma.product.findMany({
        where: {
          categoryId: src.categoryId,
          id: { not: productId, notIn: topIds },
          isAvailable: true,
        },
        select: { id: true },
        take: limit - topIds.length,
        orderBy: { createdAt: 'desc' },
      });
      topIds = [...topIds, ...fillers.map((p) => p.id)];
    }

    if (topIds.length === 0) return [];

    const products = await this.prisma.product.findMany({
      where: { id: { in: topIds }, isAvailable: true },
      include: PRODUCT_INCLUDE,
    });
    // Keep the co-occurrence ordering.
    const byId = new Map(products.map((p) => [p.id, p]));
    const ordered = topIds
      .map((id) => byId.get(id))
      .filter((p): p is NonNullable<typeof p> => p != null);

    const summaries = await this.reviewSummariesForProducts(
      ordered.map((p) => p.id),
    );
    return ordered.map((p) => ({
      ...p,
      averageRating: summaries[p.id]?.averageRating ?? 0,
      reviewCount: summaries[p.id]?.reviewCount ?? 0,
    }));
  }

  /// Aggregates avg rating + count for many products in a single round-trip.
  /// Kept here (instead of calling `ReviewsService`) to avoid a circular
  /// module dependency — Reviews already depends on Products via FK.
  private async reviewSummariesForProducts(
    productIds: string[],
  ): Promise<Record<string, { averageRating: number; reviewCount: number }>> {
    if (productIds.length === 0) return {};
    const rows = await this.prisma.review.groupBy({
      by: ['productId'],
      where: {
        productId: { in: productIds },
        status: 'PUBLISHED',
      },
      _avg: { rating: true },
      _count: { rating: true },
    });
    return Object.fromEntries(
      rows.map((r) => [
        r.productId,
        {
          averageRating: r._avg.rating ?? 0,
          reviewCount: r._count.rating ?? 0,
        },
      ]),
    );
  }

  async create(storeId: string, dto: CreateProductDto) {
    return this.prisma.product.create({
      data: {
        storeId,
        categoryId: dto.categoryId,
        name: dto.name,
        slug: dto.slug,
        description: dto.description,
        basePrice: new Prisma.Decimal(dto.basePrice),
        images: dto.images,
        tags: dto.tags ?? [],
        preparationMinutes: dto.preparationMinutes ?? 60,
        isAvailable: dto.isAvailable ?? true,
        isSeasonal: dto.isSeasonal ?? false,
        seasonStart: dto.seasonStart ? new Date(dto.seasonStart) : null,
        seasonEnd: dto.seasonEnd ? new Date(dto.seasonEnd) : null,
        leadTimeHours: dto.leadTimeHours ?? null,
        availableDaysOfWeek: dto.availableDaysOfWeek ?? [],
        dailyMaxQuantity: dto.dailyMaxQuantity ?? null,
        flavorPickCount: dto.flavorPickCount ?? null,
        flavorOptions: dto.flavorOptions ?? [],
        variants: {
          create: dto.variants.map((v) => ({
            size: v.size,
            flavor: v.flavor,
            priceDelta: new Prisma.Decimal(v.priceDelta ?? 0),
            stockMode: v.stockQty == null ? 'UNLIMITED' : 'LIMITED',
            stockQty: v.stockQty,
            isAvailable: v.isAvailable ?? true,
          })),
        },
      },
      include: PRODUCT_INCLUDE,
    });
  }

  /**
   * Diff-update for variants: rows with `id` are kept (and updated), rows
   * without `id` are created, existing rows whose `id` is absent from the
   * incoming list are deleted. Atomic via a Prisma transaction.
   */
  async update(id: string, storeId: string | null, dto: UpdateProductDto) {
    const existing = await this.findOne(id);
    if (storeId && existing.storeId !== storeId) {
      throw new BadRequestException({
        code: 'PRODUCT_NOT_IN_STORE',
        message: 'Product belongs to another store.',
      });
    }

    return this.prisma.$transaction(async (tx) => {
      const data: Prisma.ProductUpdateInput = {
        ...(dto.categoryId && { category: { connect: { id: dto.categoryId } } }),
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.slug !== undefined && { slug: dto.slug }),
        ...(dto.description !== undefined && { description: dto.description }),
        ...(dto.basePrice !== undefined && {
          basePrice: new Prisma.Decimal(dto.basePrice),
        }),
        ...(dto.images && { images: dto.images }),
        ...(dto.tags !== undefined && { tags: dto.tags }),
        ...(dto.preparationMinutes !== undefined && {
          preparationMinutes: dto.preparationMinutes,
        }),
        ...(dto.isAvailable !== undefined && { isAvailable: dto.isAvailable }),
        ...(dto.isSeasonal !== undefined && { isSeasonal: dto.isSeasonal }),
        ...(dto.seasonStart !== undefined && {
          seasonStart: dto.seasonStart ? new Date(dto.seasonStart) : null,
        }),
        ...(dto.seasonEnd !== undefined && {
          seasonEnd: dto.seasonEnd ? new Date(dto.seasonEnd) : null,
        }),
        ...(dto.leadTimeHours !== undefined && {
          leadTimeHours: dto.leadTimeHours,
        }),
        ...(dto.availableDaysOfWeek !== undefined && {
          availableDaysOfWeek: dto.availableDaysOfWeek,
        }),
        ...(dto.dailyMaxQuantity !== undefined && {
          dailyMaxQuantity: dto.dailyMaxQuantity,
        }),
        ...(dto.flavorPickCount !== undefined && {
          flavorPickCount: dto.flavorPickCount,
        }),
        ...(dto.flavorOptions !== undefined && {
          flavorOptions: dto.flavorOptions,
        }),
      };

      await tx.product.update({ where: { id }, data });

      if (dto.variants) {
        await this.reconcileVariants(tx, id, dto.variants);
      }

      return tx.product.findUniqueOrThrow({
        where: { id },
        include: PRODUCT_INCLUDE,
      });
    });
  }

  private async reconcileVariants(
    tx: Prisma.TransactionClient,
    productId: string,
    variants: VariantInputDto[],
  ) {
    const incomingIds = new Set(
      variants.filter((v) => v.id).map((v) => v.id!),
    );
    const existing = await tx.productVariant.findMany({
      where: { productId },
      select: { id: true },
    });
    const toDelete = existing
      .filter((v) => !incomingIds.has(v.id))
      .map((v) => v.id);

    if (toDelete.length > 0) {
      await tx.productVariant.deleteMany({ where: { id: { in: toDelete } } });
    }

    for (const v of variants) {
      const data = {
        size: v.size,
        flavor: v.flavor,
        priceDelta: new Prisma.Decimal(v.priceDelta ?? 0),
        stockMode: (v.stockQty == null ? 'UNLIMITED' : 'LIMITED') as
          | 'UNLIMITED'
          | 'LIMITED',
        stockQty: v.stockQty ?? null,
        isAvailable: v.isAvailable ?? true,
      };
      if (v.id) {
        await tx.productVariant.update({ where: { id: v.id }, data });
      } else {
        await tx.productVariant.create({ data: { ...data, productId } });
      }
    }
  }

  /// Returns `{ deleted, archived }` so the merchant UI can show the
  /// correct outcome message. Hard delete happens when no past order
  /// references the product; otherwise we archive (hide everywhere) since
  /// the OrderItem FK must keep pointing at a real row.
  async remove(
    id: string,
    storeId: string | null,
  ): Promise<{ deleted: boolean; archived: boolean }> {
    const existing = await this.findOne(id);
    if (storeId && existing.storeId !== storeId) {
      throw new BadRequestException({ code: 'PRODUCT_NOT_IN_STORE' });
    }
    const orderRefs = await this.prisma.orderItem.count({
      where: { productId: id },
    });
    if (orderRefs > 0) {
      await this.prisma.$transaction([
        this.prisma.collectionItem.deleteMany({ where: { productId: id } }),
        this.prisma.product.update({
          where: { id },
          data: { isAvailable: false },
        }),
      ]);
      return { deleted: false, archived: true };
    }
    try {
      await this.prisma.$transaction([
        this.prisma.collectionItem.deleteMany({ where: { productId: id } }),
        this.prisma.product.delete({ where: { id } }),
      ]);
      return { deleted: true, archived: false };
    } catch (e) {
      // Defensive: any lingering FK still leaves the merchant with a
      // working "delete" by archiving the product.
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2003'
      ) {
        await this.prisma.product.update({
          where: { id },
          data: { isAvailable: false },
        });
        return { deleted: false, archived: true };
      }
      throw e;
    }
  }

  /// Brings an archived product back to the menu. Idempotent.
  async restore(id: string, storeId: string | null) {
    const existing = await this.findOne(id);
    if (storeId && existing.storeId !== storeId) {
      throw new BadRequestException({ code: 'PRODUCT_NOT_IN_STORE' });
    }
    return this.prisma.product.update({
      where: { id },
      data: { isAvailable: true },
      include: PRODUCT_INCLUDE,
    });
  }
}

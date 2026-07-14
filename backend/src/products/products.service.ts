import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';

import { BundlesService } from '../bundles/bundles.service';
import { lockCatalogBundles } from '../common/catalog-lock';
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
  constructor(
    private readonly prisma: PrismaService,
    private readonly bundles: BundlesService,
  ) {}

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
      // Products of a hidden category are excluded from the storefront.
      category: { isHidden: false },
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
        // `id` tiebreaker makes the sort total — without it, products sharing a
        // createdAt (common after a seed / bulk import) order differently per
        // query, so offset pagination can repeat or skip a row across pages.
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
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
        // `id` tiebreaker → total order, so offset pagination can't repeat/skip
        // a product whose updatedAt ties with another's (see findAll).
        orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * perPage,
        take: perPage,
      }),
      this.prisma.product.count({ where }),
    ]);

    return { items, meta: { page, perPage, total } };
  }

  // Product detail by id. The customer/public view only sees available
  // products (archived/discontinued SKUs are hidden — `remove()` sets
  // isAvailable=false). Staff (merchant/admin) see any product, because the
  // merchant editor loads details by id through this same endpoint; the route
  // is @Public + optional-auth, so a merchant's token populates `viewerRole`.
  async findOne(id: string, viewerRole?: Role) {
    const privileged =
      viewerRole === Role.MERCHANT_OWNER ||
      viewerRole === Role.MERCHANT_STAFF ||
      viewerRole === Role.ADMIN;
    const product = await this.prisma.product.findFirst({
      where: privileged
        ? { id }
        : { id, isAvailable: true, category: { isHidden: false } },
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
      where: { id: { in: topIds }, isAvailable: true, category: { isHidden: false } },
      include: PRODUCT_INCLUDE,
    });
    // Keep the co-occurrence ordering.
    const byId = new Map(products.map((p) => [p.id, p]));
    const ordered = topIds
      .map((id) => byId.get(id))
      .filter((p): p is NonNullable<typeof p> => p != null);

    const summaries = await this.reviewSummariesForProducts(ordered.map((p) => p.id));
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
    // Guard against accidental same-name duplicates. Product is unique only on
    // [storeId, slug], NOT name, so creating a cake that already exists with a
    // different slug silently makes a second catalog row that renders twice on
    // the storefront (the Birthday-collection duplicate incident). Block it
    // up-front. Best-effort (no DB constraint — historical duplicates still
    // exist as hidden rows, which a unique index could not coexist with).
    const name = dto.name.trim();
    const clash = await this.prisma.product.findFirst({
      where: { storeId, name: { equals: name, mode: 'insensitive' } },
      select: { id: true },
    });
    if (clash) {
      throw new ConflictException({
        code: 'PRODUCT_NAME_TAKEN',
        message: `Đã có sản phẩm tên "${name}". Hãy sửa sản phẩm hiện có thay vì tạo bản trùng.`,
      });
    }
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
      // Coarse lock: serialise this product edit against combo create/update
      // and other product writes, so the post-edit combo re-validation below
      // sees a stable membership and can't race a concurrent combo change.
      await lockCatalogBundles(tx);
      // Lock affected combos BEFORE touching product/variant rows. A checkout
      // locks the combo (`bundle:<id>`) then the variant row; acquiring the
      // combo locks first here matches that order so the two can't deadlock.
      const lockedBundles = await this.bundles.lockActiveBundlesForProducts(tx, [id]);
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

      // A price / flavour-pick / selling-day / availability / variant change can
      // make a combo containing this product unfulfillable — deactivate any of
      // the (already-locked) combos that no longer validate.
      await this.bundles.deactivateInvalidBundles(tx, lockedBundles);

      return tx.product.findUniqueOrThrow({
        where: { id },
        include: PRODUCT_INCLUDE,
      });
    });
  }

  /// Deactivates every combo that contains the given product (it can no longer
  /// be fulfilled). Takes each affected combo's `bundle:<id>` advisory lock
  /// first, in sorted id order, so it serialises with an in-flight checkout
  /// that re-validates the combo (orders.service.assertBundlesUnchanged) and
  /// stays deadlock-free. Must run inside a transaction.
  private async deactivateBundlesContaining(
    tx: Prisma.TransactionClient,
    productId: string,
  ): Promise<void> {
    const affected = await tx.bundle.findMany({
      where: { items: { some: { productId } } },
      select: { id: true },
    });
    const ids = affected.map((b) => b.id).sort();
    if (ids.length === 0) return;
    for (const bid of ids) {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${'bundle:' + bid}, 0))`;
    }
    await tx.bundle.updateMany({
      where: { id: { in: ids } },
      data: { isActive: false },
    });
  }

  private async reconcileVariants(
    tx: Prisma.TransactionClient,
    productId: string,
    variants: VariantInputDto[],
  ) {
    const incomingIds = new Set(variants.filter((v) => v.id).map((v) => v.id!));
    const existing = await tx.productVariant.findMany({
      where: { productId },
      select: { id: true },
    });
    const existingIds = new Set(existing.map((v) => v.id));
    // Ownership guard: a supplied variant id must already belong to THIS
    // product. Without it, `update({ where: { id } })` would happily mutate
    // another product's variant (no productId scope on a by-id update).
    for (const v of variants) {
      if (v.id && !existingIds.has(v.id)) {
        throw new BadRequestException({
          code: 'VARIANT_NOT_IN_PRODUCT',
          message: 'Một biến thể không thuộc sản phẩm này.',
        });
      }
    }
    const toDelete = existing.filter((v) => !incomingIds.has(v.id)).map((v) => v.id);

    if (toDelete.length > 0) {
      // A combo (BundleItem) can pin a specific variant. The DB FK is
      // ON DELETE SET NULL, so deleting a pinned variant would SILENTLY null
      // the pin — and at order time the combo would re-resolve to the product's
      // canonical-first variant, shipping the wrong item at the wrong price and
      // mis-computing the combo discount. Fail loudly instead: the admin must
      // detach the variant from the combo first.
      const pinned = await tx.bundleItem.findMany({
        where: { variantId: { in: toDelete } },
        select: { bundle: { select: { name: true } } },
      });
      if (pinned.length > 0) {
        const names = [...new Set(pinned.map((p) => p.bundle.name))];
        throw new BadRequestException({
          code: 'VARIANT_PINNED_BY_BUNDLE',
          message:
            `Không thể xoá biến thể đang được combo sử dụng: ${names.join(', ')}. ` +
            `Hãy gỡ biến thể khỏi combo trước khi xoá.`,
          details: { bundles: names },
        });
      }
      await tx.productVariant.deleteMany({ where: { id: { in: toDelete } } });
    }

    for (const v of variants) {
      const data = {
        size: v.size,
        flavor: v.flavor,
        priceDelta: new Prisma.Decimal(v.priceDelta ?? 0),
        stockMode: (v.stockQty == null ? 'UNLIMITED' : 'LIMITED') as 'UNLIMITED' | 'LIMITED',
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
      await this.prisma.$transaction(async (tx) => {
        await lockCatalogBundles(tx);
        await tx.collectionItem.deleteMany({ where: { productId: id } });
        // A combo containing this product can no longer be fulfilled — deactivate
        // it so it stops showing on the storefront (otherwise it stays "buyable"
        // and every checkout fails with a confusing product-level error).
        await this.deactivateBundlesContaining(tx, id);
        await tx.product.update({
          where: { id },
          data: { isAvailable: false },
        });
      });
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
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2003') {
        await this.prisma.$transaction(async (tx) => {
          await lockCatalogBundles(tx);
          // Same as the order-ref archive path: a combo containing this product
          // can't be fulfilled, so deactivate it alongside archiving.
          await this.deactivateBundlesContaining(tx, id);
          await tx.product.update({
            where: { id },
            data: { isAvailable: false },
          });
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

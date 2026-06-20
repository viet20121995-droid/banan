import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { lockBundle, lockCatalogBundles } from '../common/catalog-lock';
import { resolveCatalogStoreId } from '../common/catalog-store';
import { PrismaService } from '../prisma/prisma.service';

import { BundleItemInputDto, CreateBundleDto, UpdateBundleDto } from './dto';

const BUNDLE_INCLUDE = {
  items: {
    include: {
      product: {
        include: {
          variants: { orderBy: [{ size: 'asc' }, { flavor: 'asc' }] },
          category: true,
        },
      },
      variant: true,
    },
  },
} satisfies Prisma.BundleInclude;

@Injectable()
export class BundlesService {
  constructor(private readonly prisma: PrismaService) {}

  /** Chain-wide catalog store — where an admin-created combo attaches. */
  catalogStoreId(): Promise<string> {
    return resolveCatalogStoreId(this.prisma);
  }

  /// Public — every active bundle, ordered by sortOrder then createdAt.
  /// Inactive bundles are hidden from the customer site entirely.
  async list() {
    return this.prisma.bundle.findMany({
      where: { isActive: true },
      include: BUNDLE_INCLUDE,
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
  }

  async homePinned() {
    return this.prisma.bundle.findMany({
      where: { isActive: true, isPinnedToHome: true },
      include: BUNDLE_INCLUDE,
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
  }

  /// Public by-id — inactive (admin-disabled / draft) combos are hidden
  /// entirely, matching list()/homePinned(). The merchant editor loads combos
  /// (incl. inactive) via findOneForMerchant instead.
  async findOne(id: string) {
    const bundle = await this.prisma.bundle.findFirst({
      where: { id, isActive: true },
      include: BUNDLE_INCLUDE,
    });
    if (!bundle) throw new NotFoundException({ code: 'BUNDLE_NOT_FOUND' });
    return bundle;
  }

  // ── Merchant-side CRUD ────────────────────────────────────────────

  /// Merchant + admin list — includes inactive bundles, ordered by
  /// sortOrder. Falls back to all stores for admin (storeId=null).
  async listForMerchant(storeIdScope: string | null) {
    return this.prisma.bundle.findMany({
      where: storeIdScope ? { storeId: storeIdScope } : undefined,
      include: BUNDLE_INCLUDE,
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
  }

  async findOneForMerchant(id: string, storeIdScope: string | null) {
    const bundle = await this.prisma.bundle.findUnique({
      where: { id },
      include: BUNDLE_INCLUDE,
    });
    if (!bundle) throw new NotFoundException({ code: 'BUNDLE_NOT_FOUND' });
    if (storeIdScope && bundle.storeId !== storeIdScope) {
      throw new NotFoundException({ code: 'BUNDLE_NOT_FOUND' });
    }
    return bundle;
  }

  async create(storeId: string, dto: CreateBundleDto) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        // Coarse lock first: serialise combo membership/validity against
        // concurrent product edits + other combo writes, and validate INSIDE
        // the lock so two admins can't both pass a now-stale check and write
        // conflicting combos.
        await lockCatalogBundles(tx);
        await this.assertItemsValid(tx, dto.items, dto.priceVnd);
        return await tx.bundle.create({
          data: {
            storeId,
            name: dto.name.trim(),
            slug: dto.slug.trim(),
            description: dto.description?.trim() || null,
            imageUrl: dto.imageUrl?.trim() || null,
            priceVnd: dto.priceVnd,
            isActive: dto.isActive ?? true,
            isPinnedToHome: dto.isPinnedToHome ?? false,
            sortOrder: dto.sortOrder ?? 0,
            items: {
              createMany: {
                data: this.normaliseItems(dto.items),
              },
            },
          },
          include: BUNDLE_INCLUDE,
        });
      });
    } catch (e) {
      this.rethrowBundleWriteError(e);
    }
  }

  async update(id: string, storeIdScope: string | null, dto: UpdateBundleDto) {
    // Scope / 404 check only — the data used for validation is re-read INSIDE
    // the lock below (the pre-lock snapshot can be stale under concurrency).
    await this.findOneForMerchant(id, storeIdScope);
    try {
      return await this.prisma.$transaction(async (tx) => {
        // Coarse lock (vs product edits + other combo writes), THEN the
        // per-combo lock (vs an in-flight checkout that re-validates this combo
        // via the same `bundle:<id>` key). Coarse-first keeps acquisition order
        // consistent and deadlock-free.
        await lockCatalogBundles(tx);
        await lockBundle(tx, id);
        // Re-read the combo UNDER the lock: the merge fallback + validation must
        // use the CURRENT committed combo, not a snapshot read before the lock,
        // or two concurrent edits (one price, one items) can each validate
        // against stale data and write an invalid combo.
        const current = await tx.bundle.findUnique({
          where: { id },
          include: BUNDLE_INCLUDE,
        });
        if (!current) throw new NotFoundException({ code: 'BUNDLE_NOT_FOUND' });
        // Validate the EFFECTIVE item set + price when items/price change OR the
        // combo is being (re)activated — re-activation must re-check that the
        // combo is still fulfillable (a component may have gone unavailable).
        const reactivating = dto.isActive === true && !current.isActive;
        if (dto.items || dto.priceVnd !== undefined || reactivating) {
          const itemsForCheck =
            dto.items ??
            current.items.map((it) => ({
              productId: it.productId,
              variantId: it.variantId ?? undefined,
              quantity: it.quantity,
            }));
          await this.assertItemsValid(tx, itemsForCheck, dto.priceVnd ?? current.priceVnd);
        }
        const updated = await tx.bundle.update({
          where: { id },
          data: {
            ...(dto.name !== undefined && { name: dto.name.trim() }),
            ...(dto.slug !== undefined && { slug: dto.slug.trim() }),
            ...(dto.description !== undefined && {
              description: dto.description.trim() || null,
            }),
            ...(dto.imageUrl !== undefined && {
              imageUrl: dto.imageUrl.trim() || null,
            }),
            ...(dto.priceVnd !== undefined && { priceVnd: dto.priceVnd }),
            ...(dto.isActive !== undefined && { isActive: dto.isActive }),
            ...(dto.isPinnedToHome !== undefined && {
              isPinnedToHome: dto.isPinnedToHome,
            }),
            ...(dto.sortOrder !== undefined && { sortOrder: dto.sortOrder }),
          },
        });
        if (dto.items) {
          await tx.bundleItem.deleteMany({ where: { bundleId: id } });
          await tx.bundleItem.createMany({
            data: this.normaliseItems(dto.items).map((it) => ({
              bundleId: id,
              ...it,
            })),
          });
        }
        return tx.bundle.findUniqueOrThrow({
          where: { id: updated.id },
          include: BUNDLE_INCLUDE,
        });
      });
    } catch (e) {
      this.rethrowBundleWriteError(e);
    }
  }

  async remove(id: string, storeIdScope: string | null) {
    await this.findOneForMerchant(id, storeIdScope);
    await this.prisma.$transaction(async (tx) => {
      // Coarse lock (vs product/combo writes) then the per-combo lock (vs an
      // in-flight checkout re-validating this combo), so the combo can't vanish
      // between the order's re-check and its commit.
      await lockCatalogBundles(tx);
      await lockBundle(tx, id);
      await tx.bundle.delete({ where: { id } });
    });
  }

  /// De-duplicates the item list by (productId, variantId) — defensive
  /// because the editor lets the merchant add the same product twice
  /// (e.g. quantity bump) and we'd otherwise violate the composite
  /// unique constraint.
  private normaliseItems(items: BundleItemInputDto[]) {
    const merged = new Map<
      string,
      { productId: string; variantId: string | null; quantity: number }
    >();
    for (const it of items) {
      const key = `${it.productId}:${it.variantId ?? ''}`;
      const existing = merged.get(key);
      if (existing) {
        existing.quantity += it.quantity;
      } else {
        merged.set(key, {
          productId: it.productId,
          variantId: it.variantId ?? null,
          quantity: it.quantity,
        });
      }
    }
    return Array.from(merged.values());
  }

  /// Validates a bundle's items + price. Products are a chain-wide catalog so
  /// any product may be included, but we verify: every product exists, each
  /// item's variant actually belongs to its product (or the product has a
  /// default variant), and the flat combo price never EXCEEDS the à-la-carte
  /// sum — a combo is a deal, not a markup; otherwise order creation would
  /// silently charge the higher regular sum (the discount clamps at 0).
  /**
   * Advisory-lock every ACTIVE combo containing any of `productIds`, in sorted
   * id order. The CALLER must already hold the catalog-bundles coarse lock (so
   * membership is stable) and MUST call this BEFORE mutating product/variant
   * rows — a checkout locks the combo (`bundle:<id>`) and then the variant row,
   * so taking the combo locks first here matches that order and avoids a
   * cross-deadlock (combo-lock-then-variant-row both sides). Returns the locked
   * combo ids for a later revalidation pass.
   */
  async lockActiveBundlesForProducts(
    tx: Prisma.TransactionClient,
    productIds: string[],
  ): Promise<string[]> {
    if (productIds.length === 0) return [];
    const rows = await tx.bundle.findMany({
      where: {
        isActive: true,
        items: { some: { productId: { in: productIds } } },
      },
      select: { id: true },
    });
    const ids = rows.map((r) => r.id).sort();
    for (const bid of ids) await lockBundle(tx, bid);
    return ids;
  }

  /**
   * Re-evaluate the given (already-locked) combos against current data and
   * deactivate the ones no longer fulfillable — a now-unavailable / flavour-pick
   * / day-conflicting / missing component, or a combo price that now exceeds the
   * à-la-carte sum. Returns the deactivated combo ids. Pair with
   * lockActiveBundlesForProducts: lock → mutate product → this.
   */
  async deactivateInvalidBundles(
    tx: Prisma.TransactionClient,
    bundleIds: string[],
  ): Promise<string[]> {
    if (bundleIds.length === 0) return [];
    const bundles = await tx.bundle.findMany({
      where: { id: { in: bundleIds }, isActive: true },
      include: BUNDLE_INCLUDE,
    });
    const toDeactivate = bundles.filter((b) => !this.isBundleStillValid(b)).map((b) => b.id);
    if (toDeactivate.length === 0) return [];
    await tx.bundle.updateMany({
      where: { id: { in: toDeactivate } },
      data: { isActive: false },
    });
    return toDeactivate;
  }

  /** Non-throwing mirror of assertItemsValid's rules, evaluated against a
   *  combo's CURRENT persisted items + product data — used by
   *  deactivateInvalidBundles to decide whether a combo survives a product
   *  edit. Mirrors assertItemsValid exactly: a component that is missing,
   *  unavailable (product OR variant), a flavour-pick, day-conflicting, or whose
   *  prices now push the combo above the à-la-carte sum makes it invalid. */
  private isBundleStillValid(
    bundle: Prisma.BundleGetPayload<{ include: typeof BUNDLE_INCLUDE }>,
  ): boolean {
    let regular = new Prisma.Decimal(0);
    const dayConstrained: number[][] = [];
    for (const it of bundle.items) {
      const product = it.product;
      if (!product || !product.isAvailable) return false;
      if (product.flavorPickCount && product.flavorPickCount > 0) return false;
      const variant = it.variant ?? product.variants[0];
      if (!variant || !variant.isAvailable) return false;
      if (product.availableDaysOfWeek.length > 0) {
        dayConstrained.push(product.availableDaysOfWeek);
      }
      regular = regular.plus(
        new Prisma.Decimal(product.basePrice).plus(variant.priceDelta).times(it.quantity),
      );
    }
    if (dayConstrained.length > 0) {
      const common = [0, 1, 2, 3, 4, 5, 6].filter((d) =>
        dayConstrained.every((days) => days.includes(d)),
      );
      if (common.length === 0) return false;
    }
    return bundle.priceVnd <= Number(regular.toString());
  }

  /** P2002 on a combo write means either a duplicate slug (→ 409) or — far less
   *  likely, normaliseItems dedupes — a duplicate (productId, variantId) item
   *  (→ 400). Discriminate on the violated constraint instead of always
   *  blaming the slug. */
  private rethrowBundleWriteError(e: unknown): never {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
      const target = Array.isArray(e.meta?.target)
        ? (e.meta?.target as string[]).join(',')
        : String(e.meta?.target ?? '');
      if (target.includes('slug')) {
        throw new ConflictException({
          code: 'BUNDLE_SLUG_TAKEN',
          message: 'Slug đã tồn tại — chọn slug khác.',
        });
      }
      throw new BadRequestException({
        code: 'BUNDLE_DUPLICATE_ITEM',
        message: 'Combo có món bị trùng — vui lòng kiểm tra lại danh sách.',
      });
    }
    throw e;
  }

  private async assertItemsValid(
    db: Prisma.TransactionClient,
    items: BundleItemInputDto[],
    priceVnd: number,
  ): Promise<void> {
    const ids = Array.from(new Set(items.map((i) => i.productId)));
    const products = await db.product.findMany({
      where: { id: { in: ids } },
      // Canonical variant ordering — must match the bundle-detail API and the
      // order-side default so `variants[0]` resolves to the SAME variant the
      // customer saw and is charged for.
      include: { variants: { orderBy: [{ size: 'asc' }, { flavor: 'asc' }] } },
    });
    const byId = new Map(products.map((p) => [p.id, p]));
    if (byId.size !== ids.length) {
      throw new BadRequestException({
        code: 'PRODUCT_NOT_FOUND',
        message: 'Một số sản phẩm không tồn tại.',
      });
    }
    let regular = new Prisma.Decimal(0);
    const dayConstrained: number[][] = [];
    for (const it of items) {
      const product = byId.get(it.productId)!;
      // An unavailable (archived/discontinued) product can't go in a combo — it
      // would make every checkout of the combo fail. Block it at config time.
      if (!product.isAvailable) {
        throw new BadRequestException({
          code: 'BUNDLE_PRODUCT_UNAVAILABLE',
          message: `"${product.name}" hiện ngừng bán nên chưa thể đưa vào combo.`,
        });
      }
      // A "pick-your-flavours" product can't live in a combo: the combo fixes
      // its contents, so no flavour composition is captured and the kitchen
      // wouldn't know what to make. Block it at configuration time.
      if (product.flavorPickCount && product.flavorPickCount > 0) {
        throw new BadRequestException({
          code: 'BUNDLE_FLAVOR_PRODUCT',
          message: `"${product.name}" cần chọn vị nên chưa thể đưa vào combo.`,
        });
      }
      const variant = it.variantId
        ? product.variants.find((v) => v.id === it.variantId)
        : product.variants[0];
      if (!variant) {
        throw new BadRequestException({
          code: it.variantId ? 'VARIANT_NOT_IN_PRODUCT' : 'PRODUCT_NO_VARIANT',
          message: `Lựa chọn không hợp lệ cho "${product.name}".`,
        });
      }
      // The chosen (or default) variant must itself be on sale.
      if (!variant.isAvailable) {
        throw new BadRequestException({
          code: 'BUNDLE_VARIANT_UNAVAILABLE',
          message: `Lựa chọn cho "${product.name}" hiện không bán.`,
        });
      }
      if (product.availableDaysOfWeek.length > 0) {
        dayConstrained.push(product.availableDaysOfWeek);
      }
      regular = regular.plus(
        new Prisma.Decimal(product.basePrice).plus(variant.priceDelta).times(it.quantity),
      );
    }
    // A combo whose parts share NO common selling day can never be fulfilled
    // on a single date — reject it rather than letting it look "any day".
    if (dayConstrained.length > 0) {
      const common = [0, 1, 2, 3, 4, 5, 6].filter((d) =>
        dayConstrained.every((days) => days.includes(d)),
      );
      if (common.length === 0) {
        throw new BadRequestException({
          code: 'BUNDLE_DAY_CONFLICT',
          message:
            'Các món trong combo không có ngày bán chung — combo sẽ không đặt ' +
            'được. Vui lòng đổi thành phần.',
        });
      }
    }
    const regularVnd = Number(regular.toString());
    if (priceVnd > regularVnd) {
      throw new BadRequestException({
        code: 'BUNDLE_PRICE_ABOVE_SUM',
        message:
          `Giá combo (${priceVnd}đ) không được cao hơn tổng giá lẻ ` +
          `(${regularVnd}đ) — combo phải là giá ưu đãi.`,
      });
    }
  }

  /// Convenience for the customer side: compute the "saved" amount in
  /// VND so the UI can show "Tiết kiệm X₫". Sums the regular line price
  /// of each item (basePrice + variant priceDelta) × qty and subtracts
  /// the bundle's flat priceVnd.
  async savings(bundleId: string): Promise<number> {
    const bundle = await this.findOne(bundleId);
    let regular = 0;
    for (const item of bundle.items) {
      const variant = item.variant ?? item.product.variants[0];
      if (!variant) continue;
      const basePrice = Number(item.product.basePrice.toString());
      const delta = Number(variant.priceDelta.toString());
      regular += (basePrice + delta) * item.quantity;
    }
    return Math.max(0, regular - bundle.priceVnd);
  }
}

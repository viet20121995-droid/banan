import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

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
    await this.assertItemsValid(dto.items, dto.priceVnd);
    try {
      const bundle = await this.prisma.bundle.create({
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
      return bundle;
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException({
          code: 'BUNDLE_SLUG_TAKEN',
          message: 'Slug đã tồn tại — chọn slug khác.',
        });
      }
      throw e;
    }
  }

  async update(id: string, storeIdScope: string | null, dto: UpdateBundleDto) {
    const existing = await this.findOneForMerchant(id, storeIdScope);
    // Validate the EFFECTIVE item set + price (merge with existing when the
    // update omits one side) so a price-only edit can't push the combo above
    // the à-la-carte sum, and new items keep valid variants.
    if (dto.items || dto.priceVnd !== undefined) {
      const itemsForCheck =
        dto.items ??
        existing.items.map((it) => ({
          productId: it.productId,
          variantId: it.variantId ?? undefined,
          quantity: it.quantity,
        }));
      await this.assertItemsValid(itemsForCheck, dto.priceVnd ?? existing.priceVnd);
    }
    try {
      return await this.prisma.$transaction(async (tx) => {
        // Serialise against an in-flight checkout of this combo: the order
        // transaction takes the same `bundle:<id>` advisory lock and re-checks
        // the combo, so an edit can't land between the order's read and its
        // commit (which would persist stale component lines / bundleDiscount).
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${'bundle:' + id}, 0))`;
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
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException({
          code: 'BUNDLE_SLUG_TAKEN',
          message: 'Slug đã tồn tại — chọn slug khác.',
        });
      }
      throw e;
    }
  }

  async remove(id: string, storeIdScope: string | null) {
    await this.findOneForMerchant(id, storeIdScope);
    await this.prisma.$transaction(async (tx) => {
      // Serialise the delete against an in-flight checkout of this combo (the
      // order tx takes the same `bundle:<id>` lock and re-validates), so the
      // combo can't vanish between the order's re-check and its commit.
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${'bundle:' + id}, 0))`;
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
  private async assertItemsValid(items: BundleItemInputDto[], priceVnd: number): Promise<void> {
    const ids = Array.from(new Set(items.map((i) => i.productId)));
    const products = await this.prisma.product.findMany({
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

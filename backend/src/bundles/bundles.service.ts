import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import {
  BundleItemInputDto,
  CreateBundleDto,
  UpdateBundleDto,
} from './dto';

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

  /// Public — every active bundle, ordered by sortOrder then createdAt.
  /// Inactive bundles are hidden from the customer site entirely.
  async list() {
    return this.prisma.bundle.findMany({
      where: { isActive: true },
      include: BUNDLE_INCLUDE,
      orderBy: [
        { sortOrder: 'asc' },
        { createdAt: 'desc' },
      ],
    });
  }

  async homePinned() {
    return this.prisma.bundle.findMany({
      where: { isActive: true, isPinnedToHome: true },
      include: BUNDLE_INCLUDE,
      orderBy: [
        { sortOrder: 'asc' },
        { createdAt: 'desc' },
      ],
    });
  }

  async findOne(id: string) {
    const bundle = await this.prisma.bundle.findUnique({
      where: { id },
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
      orderBy: [
        { sortOrder: 'asc' },
        { createdAt: 'desc' },
      ],
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
    await this.assertItemsExist(dto.items);
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
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
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
    if (dto.items) {
      await this.assertItemsExist(dto.items);
    }
    try {
      return await this.prisma.$transaction(async (tx) => {
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
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
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
    await this.prisma.bundle.delete({ where: { id } });
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

  /// Products are a single chain-wide catalog, so a bundle (at any branch) may
  /// include any catalog product — only verify they exist (the old same-store
  /// check rejected every product for non-catalog-store merchants).
  private async assertItemsExist(items: BundleItemInputDto[]): Promise<void> {
    const ids = Array.from(new Set(items.map((i) => i.productId)));
    const found = await this.prisma.product.count({
      where: { id: { in: ids } },
    });
    if (found !== ids.length) {
      throw new BadRequestException({
        code: 'PRODUCT_NOT_FOUND',
        message: 'Một số sản phẩm không tồn tại.',
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
      const variant =
        item.variant ?? item.product.variants[0];
      if (!variant) continue;
      const basePrice = Number(item.product.basePrice.toString());
      const delta = Number(variant.priceDelta.toString());
      regular += (basePrice + delta) * item.quantity;
    }
    return Math.max(0, regular - bundle.priceVnd);
  }
}

import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { ProductsService } from '../products/products.service';

import type { CreateCategoryDto, UpdateCategoryDto } from './dto/category.dto';

/** How many products a pinned-category home strip shows. */
const HOME_STRIP_LIMIT = 12;

@Injectable()
export class CategoriesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly products: ProductsService,
  ) {}

  /** All categories — the customer menu filter chips, ordered by sortOrder.
   *  Customers get visible categories only; staff pass includeHidden to also
   *  list hidden ones (so they can unhide). */
  findAll(includeHidden = false) {
    return this.prisma.category.findMany({
      where: includeHidden ? undefined : { isHidden: false },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
  }

  /** Customer home — categories pinned to home, each with a handful of
   *  available products for a featured strip (replaces the old Collection
   *  home strips). Empty pinned categories are skipped. Products are decorated
   *  with isBirthdayCake (= the category's flag, so the cake wizard fires from a
   *  strip too) + review summary, matching the /products endpoints. */
  async homePinned() {
    const categories = await this.prisma.category.findMany({
      where: {
        isPinnedToHome: true,
        isHidden: false,
        products: { some: { isAvailable: true } },
      },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      include: {
        products: {
          where: { isAvailable: true },
          include: {
            variants: { orderBy: [{ size: 'asc' }, { flavor: 'asc' }] },
          },
          orderBy: { createdAt: 'desc' },
          take: HOME_STRIP_LIMIT,
        },
      },
    });
    const summaries = await this.reviewSummaries(
      categories.flatMap((c) => c.products.map((p) => p.id)),
    );
    return categories.map((c) => ({
      ...c,
      products: c.products.map((p) => ({
        ...p,
        // Every product in this strip belongs to category c, so its birthday
        // status is c's flag.
        isBirthdayCake: c.isBirthdayCakeCategory,
        averageRating: summaries[p.id]?.averageRating ?? 0,
        reviewCount: summaries[p.id]?.reviewCount ?? 0,
      })),
    }));
  }

  /** Published-review avg + count per product. Inlined (not ReviewsService) to
   *  avoid a circular module dependency, mirroring ProductsService. */
  private async reviewSummaries(
    productIds: string[],
  ): Promise<Record<string, { averageRating: number; reviewCount: number }>> {
    if (productIds.length === 0) return {};
    const rows = await this.prisma.review.groupBy({
      by: ['productId'],
      where: { productId: { in: productIds }, status: 'PUBLISHED' },
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

  async findOne(id: string) {
    const category = await this.prisma.category.findUnique({ where: { id } });
    if (!category) throw new NotFoundException({ code: 'CATEGORY_NOT_FOUND' });
    return category;
  }

  async create(dto: CreateCategoryDto) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        // At most one birthday-cake category — clear the flag elsewhere first.
        if (dto.isBirthdayCakeCategory === true) {
          // Serialize concurrent birthday-flag writers: clear-then-set is not
          // atomic across transactions under READ COMMITTED, so without this
          // two simultaneous flag-sets could both commit true. Lock released
          // automatically at transaction end.
          await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended('category:birthday-flag', 0))`;
          await tx.category.updateMany({
            where: { isBirthdayCakeCategory: true },
            data: { isBirthdayCakeCategory: false },
          });
        }
        return tx.category.create({ data: dto });
      });
    } catch (e) {
      this.rethrowSlugConflict(e);
    }
  }

  async update(id: string, dto: UpdateCategoryDto) {
    await this.findOne(id);
    try {
      return await this.prisma.$transaction(async (tx) => {
        if (dto.isBirthdayCakeCategory === true) {
          // See create(): serialize birthday-flag writers so two concurrent
          // sets can't both end up flagged.
          await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended('category:birthday-flag', 0))`;
          await tx.category.updateMany({
            where: { isBirthdayCakeCategory: true, id: { not: id } },
            data: { isBirthdayCakeCategory: false },
          });
        }
        return tx.category.update({ where: { id }, data: dto });
      });
    } catch (e) {
      this.rethrowSlugConflict(e);
    }
  }

  /** Reorder: persist the given id → sortOrder mapping in one transaction so a
   *  drag-to-reorder in the admin lands atomically. */
  async reorder(ids: string[]): Promise<void> {
    await this.prisma.$transaction(
      ids.map((id, index) =>
        this.prisma.category.update({
          where: { id },
          data: { sortOrder: index },
        }),
      ),
    );
  }

  async remove(id: string) {
    await this.findOne(id);
    // A category with products can't be deleted (Product.categoryId is
    // required) — block it with a clear message instead of an opaque FK 500.
    const productCount = await this.prisma.product.count({
      where: { categoryId: id },
    });
    if (productCount > 0) {
      throw new BadRequestException({
        code: 'CATEGORY_HAS_PRODUCTS',
        message: `Danh mục còn ${productCount} sản phẩm — hãy chuyển sản phẩm sang danh mục khác trước khi xoá.`,
      });
    }
    await this.prisma.category.delete({ where: { id } });
  }

  /**
   * Force-delete: remove the category AND its products in one action. Products
   * that appear in an order can't be hard-deleted (OrderItem.product is
   * Restrict — deleting would destroy order history), so we refuse the whole
   * operation rather than partially wipe; the merchant should hide the category
   * instead. Order-free products are removed via ProductsService.remove (which
   * cleans their FKs + deactivates affected bundles), then the now-empty
   * category is deleted.
   *
   * ponytail: the per-product removes aren't in one transaction with the
   * category delete — acceptable for an admin cleanup action (re-run is safe);
   * wrap in a single tx if this ever needs to be atomic.
   */
  async removeWithProducts(id: string, storeId: string | null) {
    await this.findOne(id);
    const products = await this.prisma.product.findMany({
      where: { categoryId: id },
      select: { id: true },
    });
    const ids = products.map((p) => p.id);
    if (ids.length > 0) {
      const inOrders = await this.prisma.orderItem.count({
        where: { productId: { in: ids } },
      });
      if (inOrders > 0) {
        throw new BadRequestException({
          code: 'CATEGORY_PRODUCTS_IN_ORDERS',
          message:
            'Danh mục có sản phẩm đã phát sinh đơn hàng — không thể xoá (sẽ mất lịch sử đơn). Hãy ẩn danh mục thay vì xoá.',
        });
      }
      for (const pid of ids) {
        await this.products.remove(pid, storeId);
      }
    }
    await this.prisma.category.delete({ where: { id } });
  }

  private rethrowSlugConflict(e: unknown): never {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
      throw new ConflictException({
        code: 'CATEGORY_SLUG_TAKEN',
        message: 'Slug danh mục đã tồn tại — vui lòng chọn slug khác.',
      });
    }
    throw e;
  }
}

import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import type { CreateCategoryDto, UpdateCategoryDto } from './dto/category.dto';

/** How many products a pinned-category home strip shows. */
const HOME_STRIP_LIMIT = 12;

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  /** All categories — the customer menu filter chips, ordered by sortOrder. */
  findAll() {
    return this.prisma.category.findMany({
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
  }

  /** Customer home — categories pinned to home, each with a handful of
   *  available products for a featured strip (replaces the old Collection
   *  home strips). Empty pinned categories are skipped. */
  async homePinned() {
    return this.prisma.category.findMany({
      where: {
        isPinnedToHome: true,
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
  }

  async findOne(id: string) {
    const category = await this.prisma.category.findUnique({ where: { id } });
    if (!category) throw new NotFoundException({ code: 'CATEGORY_NOT_FOUND' });
    return category;
  }

  async create(dto: CreateCategoryDto) {
    try {
      return await this.prisma.category.create({ data: dto });
    } catch (e) {
      this.rethrowSlugConflict(e);
    }
  }

  async update(id: string, dto: UpdateCategoryDto) {
    await this.findOne(id);
    try {
      return await this.prisma.category.update({ where: { id }, data: dto });
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

import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

const WISHLIST_INCLUDE = {
  product: {
    include: {
      variants: true,
      category: true,
      store: { select: { id: true, name: true, slug: true } },
    },
  },
} satisfies Prisma.WishlistItemInclude;

@Injectable()
export class WishlistService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string, page = 1, perPage = 30) {
    const where: Prisma.WishlistItemWhereInput = { userId };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.wishlistItem.findMany({
        where,
        include: WISHLIST_INCLUDE,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * perPage,
        take: perPage,
      }),
      this.prisma.wishlistItem.count({ where }),
    ]);
    return { items, meta: { page, perPage, total } };
  }

  /// Compact list of just the product ids — used by the menu screen to
  /// decorate the heart icon on each `ProductCard`.
  async listProductIds(userId: string): Promise<string[]> {
    const rows = await this.prisma.wishlistItem.findMany({
      where: { userId },
      select: { productId: true },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((r) => r.productId);
  }

  async add(userId: string, productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { id: true },
    });
    if (!product) {
      throw new NotFoundException({ code: 'PRODUCT_NOT_FOUND' });
    }
    try {
      const item = await this.prisma.wishlistItem.create({
        data: { userId, productId },
        include: WISHLIST_INCLUDE,
      });
      return item;
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        // Already in the wishlist — idempotent: return the existing row.
        return this.prisma.wishlistItem.findUniqueOrThrow({
          where: { userId_productId: { userId, productId } },
          include: WISHLIST_INCLUDE,
        });
      }
      throw e;
    }
  }

  async remove(userId: string, productId: string) {
    const deleted = await this.prisma.wishlistItem
      .delete({
        where: { userId_productId: { userId, productId } },
      })
      .catch((e) => {
        if (
          e instanceof Prisma.PrismaClientKnownRequestError &&
          e.code === 'P2025'
        ) {
          return null; // not in wishlist — idempotent.
        }
        throw e;
      });
    if (!deleted) {
      throw new BadRequestException({
        code: 'NOT_IN_WISHLIST',
        message: 'Sản phẩm chưa có trong danh sách yêu thích.',
      });
    }
    return { ok: true };
  }
}

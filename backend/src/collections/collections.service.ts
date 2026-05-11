import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import type {
  CollectionItemInputDto,
  CreateCollectionDto,
  UpdateCollectionDto,
} from './dto/collection.dto';

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
    orderBy: { sortOrder: 'asc' },
  },
} satisfies Prisma.CollectionInclude;

@Injectable()
export class CollectionsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Public read — pinned + active collections shown on customer home. */
  async listForHome(storeId?: string) {
    return this.prisma.collection.findMany({
      where: {
        isActive: true,
        isPinnedToHome: true,
        ...(storeId && { storeId }),
        // Items must be present and the product still available.
        items: { some: { product: { isAvailable: true } } },
      },
      include: COLLECTION_INCLUDE,
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
  }

  /** Merchant-side list — every collection for the store. */
  async listForStore(storeId: string) {
    return this.prisma.collection.findMany({
      where: { storeId },
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
    return collection;
  }

  async create(storeId: string, dto: CreateCollectionDto) {
    if (dto.items) await this.assertProductsBelongToStore(storeId, dto.items);
    return this.prisma.collection.create({
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
  }

  async update(id: string, storeIdScope: string | null, dto: UpdateCollectionDto) {
    const existing = await this.findOne(id, storeIdScope);
    if (dto.items) {
      await this.assertProductsBelongToStore(existing.storeId, dto.items);
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.collection.update({
        where: { id },
        data: {
          ...(dto.name !== undefined && { name: dto.name }),
          ...(dto.slug !== undefined && { slug: dto.slug }),
          ...(dto.description !== undefined && { description: dto.description }),
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
            productId: { notIn: incomingProductIds.length > 0 ? incomingProductIds : ['__none__'] },
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
  }

  async remove(id: string, storeIdScope: string | null): Promise<void> {
    await this.findOne(id, storeIdScope);
    await this.prisma.collection.delete({ where: { id } });
  }

  private async assertProductsBelongToStore(
    storeId: string,
    items: CollectionItemInputDto[],
  ) {
    if (items.length === 0) return;
    const ids = items.map((i) => i.productId);
    const products = await this.prisma.product.findMany({
      where: { id: { in: ids } },
      select: { id: true, storeId: true },
    });
    const wrongStore = products.find((p) => p.storeId !== storeId);
    if (wrongStore) {
      throw new BadRequestException({
        code: 'PRODUCT_NOT_IN_STORE',
        message: 'Cannot add a product from another store to a collection.',
      });
    }
    if (products.length !== new Set(ids).size) {
      throw new BadRequestException({
        code: 'PRODUCT_NOT_FOUND',
        message: 'One or more products in the collection no longer exist.',
      });
    }
  }
}

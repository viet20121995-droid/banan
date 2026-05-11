import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

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

    return { items, meta: { page, perPage, total } };
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

  async findOne(id: string) {
    const product = await this.prisma.product.findUnique({
      where: { id },
      include: PRODUCT_INCLUDE,
    });
    if (!product) throw new NotFoundException({ code: 'PRODUCT_NOT_FOUND' });
    return product;
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

  async remove(id: string, storeId: string | null) {
    const existing = await this.findOne(id);
    if (storeId && existing.storeId !== storeId) {
      throw new BadRequestException({ code: 'PRODUCT_NOT_IN_STORE' });
    }
    await this.prisma.product.delete({ where: { id } });
  }
}

import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { OrderStatus, Prisma, ReviewStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

import { CreateReviewDto } from './dto/create-review.dto';
import { ListReviewsDto } from './dto/list-reviews.dto';
import { ModerateReviewDto } from './dto/moderate-review.dto';

const REVIEW_INCLUDE = {
  user: { select: { id: true, fullName: true, avatarUrl: true } },
  product: { select: { id: true, name: true, slug: true, images: true } },
} satisfies Prisma.ReviewInclude;

/// Orders in these statuses are considered "received" — the customer has the
/// product in hand and is allowed to review it.
const REVIEW_ELIGIBLE_STATUSES: OrderStatus[] = [
  OrderStatus.READY_FOR_PICKUP,
  OrderStatus.DELIVERING,
  OrderStatus.COMPLETED,
];

@Injectable()
export class ReviewsService {
  private readonly logger = new Logger(ReviewsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
  ) {}

  /// Public — list PUBLISHED reviews for a product, newest first.
  async findPublicForProduct(productId: string, page = 1, perPage = 20) {
    const where: Prisma.ReviewWhereInput = {
      productId,
      status: ReviewStatus.PUBLISHED,
    };
    const [items, total, agg] = await this.prisma.$transaction([
      this.prisma.review.findMany({
        where,
        include: REVIEW_INCLUDE,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * perPage,
        take: perPage,
      }),
      this.prisma.review.count({ where }),
      this.prisma.review.aggregate({
        where,
        _avg: { rating: true },
        _count: { rating: true },
      }),
    ]);
    return {
      items,
      meta: { page, perPage, total },
      summary: {
        averageRating: agg._avg.rating ?? 0,
        totalReviews: agg._count.rating ?? 0,
      },
    };
  }

  /// Bulk fetch summary (avg + count) for many products in one round-trip.
  /// Used to decorate the catalog list with `averageRating` / `reviewCount`.
  async summariesForProducts(
    productIds: string[],
  ): Promise<Record<string, { averageRating: number; reviewCount: number }>> {
    if (productIds.length === 0) return {};
    const rows = await this.prisma.review.groupBy({
      by: ['productId'],
      where: {
        productId: { in: productIds },
        status: ReviewStatus.PUBLISHED,
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

  /// The customer's own reviews — used by the "My reviews" tab.
  async findMine(userId: string, page = 1, perPage = 20) {
    const where: Prisma.ReviewWhereInput = { userId };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.review.findMany({
        where,
        include: REVIEW_INCLUDE,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * perPage,
        take: perPage,
      }),
      this.prisma.review.count({ where }),
    ]);
    return { items, meta: { page, perPage, total } };
  }

  /// Used by the customer order detail to show "Đánh giá" CTA only on
  /// items the customer hasn't reviewed yet, and lock past-reviewed ones.
  async findByUserAndOrder(userId: string, orderId: string) {
    return this.prisma.review.findMany({
      where: { userId, orderId },
      select: { id: true, productId: true, rating: true, body: true },
    });
  }

  async create(userId: string, dto: CreateReviewDto) {
    const order = await this.prisma.order.findUnique({
      where: { id: dto.orderId },
      select: {
        id: true,
        customerId: true,
        status: true,
        items: { select: { productId: true } },
      },
    });
    if (!order || order.customerId !== userId) {
      throw new NotFoundException({ code: 'ORDER_NOT_FOUND' });
    }
    if (!REVIEW_ELIGIBLE_STATUSES.includes(order.status)) {
      throw new BadRequestException({
        code: 'ORDER_NOT_ELIGIBLE_FOR_REVIEW',
        message: 'Bạn chỉ có thể đánh giá sau khi đơn hàng đã giao hoặc sẵn sàng nhận.',
      });
    }
    if (!order.items.some((i) => i.productId === dto.productId)) {
      throw new BadRequestException({
        code: 'PRODUCT_NOT_IN_ORDER',
        message: 'Sản phẩm này không nằm trong đơn hàng đó.',
      });
    }

    // Upsert — repeat reviews update the existing one (composite unique).
    const review = await this.prisma.review.upsert({
      where: {
        productId_userId: {
          productId: dto.productId,
          userId,
        },
      },
      update: {
        rating: dto.rating,
        body: dto.body,
        images: dto.images ?? [],
        orderId: dto.orderId,
        status: ReviewStatus.PUBLISHED,
      },
      create: {
        productId: dto.productId,
        userId,
        orderId: dto.orderId,
        rating: dto.rating,
        body: dto.body,
        images: dto.images ?? [],
        status: ReviewStatus.PUBLISHED,
      },
      include: REVIEW_INCLUDE,
    });

    this.realtime.emit(['public'], 'review.created', {
      id: review.id,
      productId: review.productId,
    });
    return review;
  }

  async remove(userId: string, id: string) {
    const review = await this.prisma.review.findUnique({ where: { id } });
    if (!review || review.userId !== userId) {
      throw new NotFoundException({ code: 'REVIEW_NOT_FOUND' });
    }
    await this.prisma.review.delete({ where: { id } });
    return { ok: true };
  }

  // ── Merchant moderation ─────────────────────────────────────────────

  async findAllForMerchant(
    filters: ListReviewsDto & { status?: ReviewStatus },
    storeId: string | null,
  ) {
    const page = filters.page ?? 1;
    const perPage = filters.perPage ?? 30;
    const where: Prisma.ReviewWhereInput = {
      ...(filters.productId && { productId: filters.productId }),
      ...(filters.status && { status: filters.status }),
      // Scope a merchant/staff to their own store's products; admin (null)
      // sees every store's reviews.
      ...(storeId && { product: { storeId } }),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.review.findMany({
        where,
        include: REVIEW_INCLUDE,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * perPage,
        take: perPage,
      }),
      this.prisma.review.count({ where }),
    ]);
    return { items, meta: { page, perPage, total } };
  }

  async moderate(id: string, dto: ModerateReviewDto, actorId: string, storeId: string | null) {
    const existing = await this.prisma.review.findUnique({
      where: { id },
      select: { id: true, status: true, product: { select: { storeId: true } } },
    });
    if (!existing) {
      throw new NotFoundException({ code: 'REVIEW_NOT_FOUND' });
    }
    // A merchant/staff may only moderate reviews of their own store's
    // products; admin (null) may moderate any.
    if (storeId && existing.product.storeId !== storeId) {
      throw new ForbiddenException({ code: 'AUTH_FORBIDDEN' });
    }
    const review = await this.prisma.review.update({
      where: { id },
      data: {
        status: dto.status,
        moderationNote: dto.moderationNote,
      },
      include: REVIEW_INCLUDE,
    });
    this.realtime.emit(['public'], 'review.updated', {
      id: review.id,
      productId: review.productId,
      status: review.status,
    });
    // Audit trail: who changed which review's visibility, from → to. Emitted
    // as a structured log line (greppable / shippable to a log aggregator)
    // until a dedicated moderation-log table is warranted.
    this.logger.log(
      `review.moderate review=${review.id} by=${actorId} ${existing.status}->${review.status}` +
        (dto.moderationNote ? ` note=${JSON.stringify(dto.moderationNote)}` : ''),
    );
    return review;
  }
}

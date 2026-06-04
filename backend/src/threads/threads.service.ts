import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import type { CreateThreadDto, UpdateThreadDto } from './dto/thread.dto';

const THREAD_INCLUDE = {
  author: { select: { id: true, fullName: true, avatarUrl: true } },
  store: { select: { id: true, name: true, slug: true } },
  product: {
    select: { id: true, name: true, slug: true, images: true, basePrice: true },
  },
} satisfies Prisma.ThreadInclude;

/// Pulls `#hashtag` tokens out of free text. Lowercased, de-duped, max 15.
function extractHashtags(body: string): string[] {
  const matches = body.match(/#[\p{L}0-9_]+/gu) ?? [];
  const seen = new Set<string>();
  for (const m of matches) {
    const tag = m.slice(1).toLowerCase();
    if (tag.length > 0) seen.add(tag);
    if (seen.size >= 15) break;
  }
  return [...seen];
}

@Injectable()
export class ThreadsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Public feed — published only, newest first, optionally filtered by
   * store and/or a single hashtag. */
  async listPublished(
    opts: { storeId?: string; limit?: number; hashtag?: string } = {},
  ) {
    return this.prisma.thread.findMany({
      where: {
        publishedAt: { not: null },
        ...(opts.storeId && { storeId: opts.storeId }),
        ...(opts.hashtag && {
          hashtags: { has: opts.hashtag.toLowerCase() },
        }),
      },
      include: THREAD_INCLUDE,
      orderBy: { publishedAt: 'desc' },
      take: opts.limit ?? 10,
    });
  }

  /** Merchant inbox — drafts + published, newest first. */
  async listForStore(storeId: string) {
    return this.prisma.thread.findMany({
      where: { storeId },
      include: THREAD_INCLUDE,
      orderBy: [{ publishedAt: 'desc' }, { createdAt: 'desc' }],
    });
  }

  async findOne(id: string, storeIdScope: string | null) {
    const thread = await this.prisma.thread.findUnique({
      where: { id },
      include: THREAD_INCLUDE,
    });
    if (!thread) throw new NotFoundException({ code: 'THREAD_NOT_FOUND' });
    if (storeIdScope && thread.storeId !== storeIdScope) {
      throw new ForbiddenException({ code: 'AUTH_FORBIDDEN' });
    }
    return thread;
  }

  /** Public — bump the impression counter (best-effort, never throws). */
  async incrementView(id: string): Promise<void> {
    try {
      await this.prisma.thread.update({
        where: { id },
        data: { viewCount: { increment: 1 } },
      });
    } catch {
      // thread may have been deleted; ignore
    }
  }

  async create(storeId: string, authorId: string, dto: CreateThreadDto) {
    const images = dto.images ?? [];
    return this.prisma.thread.create({
      data: {
        storeId,
        authorId,
        title: dto.title,
        body: dto.body,
        imageUrl: dto.imageUrl ?? (images.length > 0 ? images[0] : null),
        images,
        hashtags: extractHashtags(dto.body),
        productId: dto.productId ?? null,
        ctaLabel: dto.ctaLabel ?? null,
        ctaUrl: dto.ctaUrl ?? null,
        scheduledPublishAt: dto.scheduledPublishAt
          ? new Date(dto.scheduledPublishAt)
          : null,
        publishedAt: dto.publish ? new Date() : null,
      },
      include: THREAD_INCLUDE,
    });
  }

  async update(id: string, storeIdScope: string | null, dto: UpdateThreadDto) {
    const existing = await this.findOne(id, storeIdScope);
    return this.prisma.thread.update({
      where: { id: existing.id },
      data: {
        ...(dto.title !== undefined && { title: dto.title }),
        ...(dto.body !== undefined && {
          body: dto.body,
          hashtags: extractHashtags(dto.body),
        }),
        ...(dto.imageUrl !== undefined && { imageUrl: dto.imageUrl }),
        ...(dto.images !== undefined && {
          images: dto.images,
          imageUrl: dto.images.length > 0 ? dto.images[0] : null,
        }),
        ...(dto.productId !== undefined && { productId: dto.productId }),
        ...(dto.ctaLabel !== undefined && { ctaLabel: dto.ctaLabel }),
        ...(dto.ctaUrl !== undefined && { ctaUrl: dto.ctaUrl }),
        ...(dto.scheduledPublishAt !== undefined && {
          scheduledPublishAt: dto.scheduledPublishAt
            ? new Date(dto.scheduledPublishAt)
            : null,
        }),
        ...(dto.publish !== undefined && {
          // Re-publish only updates the timestamp on a transition from draft.
          publishedAt: dto.publish
            ? (existing.publishedAt ?? new Date())
            : null,
        }),
      },
      include: THREAD_INCLUDE,
    });
  }

  async remove(id: string, storeIdScope: string | null): Promise<void> {
    await this.findOne(id, storeIdScope);
    await this.prisma.thread.delete({ where: { id } });
  }

  /**
   * Cron hook: publish any draft whose `scheduledPublishAt` is now in the
   * past. Idempotent — once `publishedAt` is set it's skipped.
   */
  async publishDueScheduled(): Promise<number> {
    const due = await this.prisma.thread.findMany({
      where: {
        publishedAt: null,
        scheduledPublishAt: { not: null, lte: new Date() },
      },
      select: { id: true },
    });
    if (due.length === 0) return 0;
    await this.prisma.thread.updateMany({
      where: { id: { in: due.map((t) => t.id) } },
      data: { publishedAt: new Date() },
    });
    return due.length;
  }
}

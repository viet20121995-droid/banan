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
} satisfies Prisma.ThreadInclude;

@Injectable()
export class ThreadsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Public feed — published only, newest first, optionally filtered by store. */
  async listPublished(opts: { storeId?: string; limit?: number } = {}) {
    return this.prisma.thread.findMany({
      where: {
        publishedAt: { not: null },
        ...(opts.storeId && { storeId: opts.storeId }),
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

  async create(storeId: string, authorId: string, dto: CreateThreadDto) {
    return this.prisma.thread.create({
      data: {
        storeId,
        authorId,
        title: dto.title,
        body: dto.body,
        imageUrl: dto.imageUrl,
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
        ...(dto.body !== undefined && { body: dto.body }),
        ...(dto.imageUrl !== undefined && { imageUrl: dto.imageUrl }),
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
}

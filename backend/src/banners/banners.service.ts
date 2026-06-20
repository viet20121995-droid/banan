import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import type { Banner } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

interface BannerInput {
  imageUrl?: string;
  title?: string;
  ctaUrl?: string;
  sortOrder?: number;
  isActive?: boolean;
}

@Injectable()
export class BannersService {
  constructor(private readonly prisma: PrismaService) {}

  /** Public — active banners for the customer hero carousel. */
  async listPublic() {
    const banners = await this.prisma.banner.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
    return banners.map((b) => BannersService.view(b));
  }

  /** Merchant — their store's banners + chain-wide (admin sees all). */
  async listForStore(storeId: string | null) {
    const where = storeId === null ? {} : { OR: [{ storeId }, { storeId: null }] };
    const banners = await this.prisma.banner.findMany({
      where,
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
    return banners.map((b) => BannersService.view(b, storeId));
  }

  async create(storeId: string | null, dto: BannerInput) {
    const created = await this.prisma.banner.create({
      data: {
        imageUrl: (dto.imageUrl ?? '').trim(),
        title: dto.title?.trim() || null,
        ctaUrl: dto.ctaUrl?.trim() || null,
        sortOrder: dto.sortOrder ?? 0,
        isActive: dto.isActive ?? true,
        storeId: storeId ?? null,
      },
    });
    return BannersService.view(created, storeId);
  }

  async update(storeId: string | null, id: string, dto: BannerInput) {
    await this.owned(storeId, id);
    const updated = await this.prisma.banner.update({
      where: { id },
      data: {
        ...(dto.imageUrl !== undefined ? { imageUrl: dto.imageUrl.trim() } : {}),
        ...(dto.title !== undefined ? { title: dto.title.trim() || null } : {}),
        ...(dto.ctaUrl !== undefined ? { ctaUrl: dto.ctaUrl.trim() || null } : {}),
        ...(dto.sortOrder !== undefined ? { sortOrder: dto.sortOrder } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
      },
    });
    return BannersService.view(updated, storeId);
  }

  async remove(storeId: string | null, id: string): Promise<void> {
    await this.owned(storeId, id);
    await this.prisma.banner.delete({ where: { id } });
  }

  private async owned(storeId: string | null, id: string): Promise<Banner> {
    const banner = await this.prisma.banner.findUnique({ where: { id } });
    if (!banner) {
      throw new NotFoundException({ code: 'BANNER_NOT_FOUND' });
    }
    // Store staff may only mutate their own store's banners; admin (null)
    // may mutate anything.
    if (storeId !== null && banner.storeId !== storeId) {
      throw new ForbiddenException({ code: 'BANNER_NOT_YOURS' });
    }
    return banner;
  }

  private static view(b: Banner, viewerStoreId?: string | null) {
    return {
      id: b.id,
      imageUrl: b.imageUrl,
      title: b.title,
      ctaUrl: b.ctaUrl,
      sortOrder: b.sortOrder,
      isActive: b.isActive,
      chainWide: b.storeId === null,
      editable:
        viewerStoreId === undefined ? true : viewerStoreId === null || b.storeId === viewerStoreId,
    };
  }
}

import { Injectable } from '@nestjs/common';
import type { PromoPopup } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

/**
 * Singleton (id = "default") admin-tunable promo popup shown on the
 * customer menu. Bumping `version` makes every client re-display, even
 * for customers who previously dismissed.
 */
@Injectable()
export class PromoPopupService {
  constructor(private readonly prisma: PrismaService) {}

  /// Always returns a row — defensively upserts on first call in case the
  /// seed insert from the migration was rolled back / missing.
  async get(): Promise<PromoPopup> {
    return this.prisma.promoPopup.upsert({
      where: { id: 'default' },
      create: { id: 'default' },
      update: {},
    });
  }

  async update(patch: {
    isActive?: boolean;
    title?: string;
    body?: string;
    imageUrl?: string | null;
    ctaLabel?: string | null;
    ctaUrl?: string | null;
    countdownSeconds?: number;
    bumpVersion?: boolean;
  }): Promise<PromoPopup> {
    const trimmedTitle = patch.title?.trim();
    const trimmedImage =
      patch.imageUrl === undefined
        ? undefined
        : patch.imageUrl?.trim()
          ? patch.imageUrl.trim()
          : null;
    const trimmedCtaLabel =
      patch.ctaLabel === undefined
        ? undefined
        : patch.ctaLabel?.trim()
          ? patch.ctaLabel.trim()
          : null;
    const trimmedCtaUrl =
      patch.ctaUrl === undefined
        ? undefined
        : patch.ctaUrl?.trim()
          ? patch.ctaUrl.trim()
          : null;

    // Ensure the singleton row exists before applying the patch — the
    // `increment` operator below only works in `update`, not `create`.
    await this.prisma.promoPopup.upsert({
      where: { id: 'default' },
      create: { id: 'default' },
      update: {},
    });

    return this.prisma.promoPopup.update({
      where: { id: 'default' },
      data: {
        isActive: patch.isActive,
        title: trimmedTitle,
        body: patch.body,
        imageUrl: trimmedImage,
        ctaLabel: trimmedCtaLabel,
        ctaUrl: trimmedCtaUrl,
        countdownSeconds: patch.countdownSeconds,
        ...(patch.bumpVersion ? { version: { increment: 1 } } : {}),
      },
    });
  }
}

import { Injectable } from '@nestjs/common';
import type { DeliveryConfig } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

/**
 * Reads / writes the admin-tunable delivery-pricing config. Stored as a
 * singleton row (id = "default") so a single update mutates the live
 * fees for every order from that moment on.
 *
 * Pricing layout (two tiers × two ward-equality bands):
 *   - Standard products
 *       same ward  as routed store → `standardFeeSameWardVnd`  (often 0)
 *       other ward                 → `standardFeeOtherWardVnd` (default 30k)
 *   - Birthday cake collection
 *       same ward  → `birthdayCakeFeeSameWardVnd`  (default 30k)
 *       other ward → `birthdayCakeFeeOtherWardVnd` (default 70k)
 *
 * Tier picked when *any* item in the cart belongs to the collection
 * identified by `birthdayCakeCollectionSlug`.
 */
@Injectable()
export class DeliveryConfigService {
  constructor(private readonly prisma: PrismaService) {}

  async get(): Promise<DeliveryConfig> {
    // The migration seeds the "default" row, so this should always find one.
    // We upsert defensively in case the row was deleted by hand.
    return this.prisma.deliveryConfig.upsert({
      where: { id: 'default' },
      create: { id: 'default' },
      update: {},
    });
  }

  async update(patch: {
    standardFeeSameWardVnd?: number;
    standardFeeOtherWardVnd?: number;
    birthdayCakeFeeSameWardVnd?: number;
    birthdayCakeFeeOtherWardVnd?: number;
    birthdayCakeCollectionSlug?: string;
  }): Promise<DeliveryConfig> {
    return this.prisma.deliveryConfig.upsert({
      where: { id: 'default' },
      create: { id: 'default', ...patch },
      update: patch,
    });
  }

  /**
   * Returns the fee for a delivery given the customer ward, the routed
   * store's ward, and whether any cart item triggers the birthday-cake
   * tier. Same-ward check is null-safe — when either ward is unknown
   * we fall back to the "other ward" rate so we never undercharge.
   */
  feeFor(
    config: DeliveryConfig,
    customerWardCode: string | null | undefined,
    storeWardCode: string | null | undefined,
    hasBirthdayCake: boolean,
  ): number {
    const sameWard =
      customerWardCode != null && storeWardCode != null && customerWardCode === storeWardCode;
    if (hasBirthdayCake) {
      return sameWard ? config.birthdayCakeFeeSameWardVnd : config.birthdayCakeFeeOtherWardVnd;
    }
    return sameWard ? config.standardFeeSameWardVnd : config.standardFeeOtherWardVnd;
  }

  /// True when any of the given product ids belongs to the birthday-cake
  /// collection (matched by `birthdayCakeCollectionSlug` on the config).
  async cartHasBirthdayCake(productIds: string[], config?: DeliveryConfig): Promise<boolean> {
    if (productIds.length === 0) return false;
    const slug = (config ?? (await this.get())).birthdayCakeCollectionSlug;
    if (!slug) return false;
    const count = await this.prisma.collectionItem.count({
      where: {
        productId: { in: productIds },
        collection: { slug },
      },
    });
    return count > 0;
  }
}

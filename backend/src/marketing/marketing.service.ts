import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import { MARKETING_DEFAULTS } from './defaults';

const ID = 'default';

export interface MarketingConfigView {
  referral: { enabled: boolean; config: unknown };
  giftCard: { enabled: boolean; config: unknown };
  subscription: { enabled: boolean; config: unknown };
  catering: { enabled: boolean; config: unknown };
  rewards: { enabled: boolean; config: unknown };
}

/** Partial patch accepted from the admin editor. */
export interface MarketingPatch {
  referralEnabled?: boolean;
  referralConfig?: unknown;
  giftCardEnabled?: boolean;
  giftCardConfig?: unknown;
  subscriptionEnabled?: boolean;
  subscriptionConfig?: unknown;
  cateringEnabled?: boolean;
  cateringConfig?: unknown;
  rewardsEnabled?: boolean;
  rewardsConfig?: unknown;
}

@Injectable()
export class MarketingService {
  constructor(private readonly prisma: PrismaService) {}

  /** Returns flags + config, each config merged over its built-in default. */
  async get(): Promise<MarketingConfigView> {
    const row = await this.prisma.marketingConfig.findUnique({
      where: { id: ID },
    });
    const cfg = (stored: unknown, def: unknown) =>
      stored && typeof stored === 'object' ? { ...(def as object), ...(stored as object) } : def;
    return {
      referral: {
        enabled: row?.referralEnabled ?? false,
        config: cfg(row?.referralConfig, MARKETING_DEFAULTS.referral),
      },
      giftCard: {
        enabled: row?.giftCardEnabled ?? false,
        config: cfg(row?.giftCardConfig, MARKETING_DEFAULTS.giftCard),
      },
      subscription: {
        enabled: row?.subscriptionEnabled ?? false,
        config: cfg(row?.subscriptionConfig, MARKETING_DEFAULTS.subscription),
      },
      catering: {
        enabled: row?.cateringEnabled ?? false,
        config: cfg(row?.cateringConfig, MARKETING_DEFAULTS.catering),
      },
      rewards: {
        enabled: row?.rewardsEnabled ?? false,
        config: cfg(row?.rewardsConfig, MARKETING_DEFAULTS.rewards),
      },
    };
  }

  /** Upsert any subset of flags / configs. */
  async update(patch: MarketingPatch): Promise<MarketingConfigView> {
    const data: Prisma.MarketingConfigUncheckedCreateInput = { id: ID };
    const j = (v: unknown) => v as Prisma.InputJsonValue;

    if (patch.referralEnabled !== undefined) data.referralEnabled = patch.referralEnabled;
    if (patch.referralConfig !== undefined) data.referralConfig = j(patch.referralConfig);
    if (patch.giftCardEnabled !== undefined) data.giftCardEnabled = patch.giftCardEnabled;
    if (patch.giftCardConfig !== undefined) data.giftCardConfig = j(patch.giftCardConfig);
    if (patch.subscriptionEnabled !== undefined)
      data.subscriptionEnabled = patch.subscriptionEnabled;
    if (patch.subscriptionConfig !== undefined)
      data.subscriptionConfig = j(patch.subscriptionConfig);
    if (patch.cateringEnabled !== undefined) data.cateringEnabled = patch.cateringEnabled;
    if (patch.cateringConfig !== undefined) data.cateringConfig = j(patch.cateringConfig);
    if (patch.rewardsEnabled !== undefined) data.rewardsEnabled = patch.rewardsEnabled;
    if (patch.rewardsConfig !== undefined) data.rewardsConfig = j(patch.rewardsConfig);

    // `id` is fixed (ID) and only set on create — strip it from the update clause.
    const update = { ...data };
    delete update.id;
    await this.prisma.marketingConfig.upsert({
      where: { id: ID },
      create: data,
      update,
    });
    return this.get();
  }
}

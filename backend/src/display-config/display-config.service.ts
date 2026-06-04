import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DisplayConfigService {
  constructor(private readonly prisma: PrismaService) {}

  /// Singleton fetch — auto-creates the default row on first call so the
  /// customer site never has to handle "config missing".
  async get() {
    return this.prisma.displayConfig.upsert({
      where: { id: 'default' },
      create: { id: 'default' },
      update: {},
    });
  }

  async update(patch: {
    showStockToCustomers?: boolean;
    contactPhone?: string;
    contactZaloOaId?: string;
    contactMessengerId?: string;
    contactEmail?: string;
  }) {
    // Empty-string from the merchant form means "clear this channel".
    // Normalise to null so the customer side can treat empty == not
    // configured uniformly.
    const norm = (v?: string) =>
      v === undefined ? undefined : v.trim() === '' ? null : v.trim();
    return this.prisma.displayConfig.upsert({
      where: { id: 'default' },
      create: { id: 'default', ...patch },
      update: {
        ...(patch.showStockToCustomers !== undefined && {
          showStockToCustomers: patch.showStockToCustomers,
        }),
        contactPhone: norm(patch.contactPhone),
        contactZaloOaId: norm(patch.contactZaloOaId),
        contactMessengerId: norm(patch.contactMessengerId),
        contactEmail: norm(patch.contactEmail),
      },
    });
  }
}

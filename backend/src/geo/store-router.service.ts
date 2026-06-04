import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

import { findWard, haversineKm, HcmWard } from './hcm-wards';

export interface RoutedStore {
  storeId: string;
  storeName: string;
  storeAddress: string;
  /// Distance in km from the address ward centroid to the picked store.
  distanceKm: number;
  /// HCMC ward this branch sits in. Used by the ward-equality delivery
  /// fee rule (same as customer ward ⇒ cheaper).
  storeWardCode: string | null;
}

/**
 * Picks the best Banan branch to fulfill a DELIVERY order. The current
 * rule: nearest branch (by haversine distance from the address ward
 * centroid) whose master + delivery pause flags are both off. Stores
 * without coordinates are skipped so we never compare against null.
 *
 * Single source of truth — used both by:
 *   - `GET /geo/delivery-quote` (live price preview on checkout)
 *   - `OrdersService.create`     (final routing when the order is placed)
 *
 * so the customer always sees the same fee they end up paying.
 */
@Injectable()
export class StoreRouterService {
  constructor(private readonly prisma: PrismaService) {}

  /// Resolves the fulfilling branch for a given ward. Returns null when the
  /// ward is unknown, has no eligible stores, or no store has coordinates.
  async pickNearestDeliveryStore(
    wardCode: string | null | undefined,
  ): Promise<RoutedStore | null> {
    const ward = findWard(wardCode);
    if (!ward) return null;
    return this.pickNearestForPoint(ward);
  }

  /// Same as above but for an arbitrary point — exposed in case we add a
  /// "use my GPS location" feature later. Stays in this service so the
  /// filtering rules (pause flags, missing coords) live in one place.
  async pickNearestForPoint(point: {
    lat: number;
    lng: number;
  }): Promise<RoutedStore | null> {
    // Only branches accepting delivery — both master and channel pause
    // must be off. NULL lat/lng excluded so we don't compute against
    // missing data.
    const candidates = await this.prisma.store.findMany({
      where: {
        isPaused: false,
        isDeliveryPaused: false,
        lat: { not: null },
        lng: { not: null },
      },
      select: {
        id: true,
        name: true,
        address: true,
        lat: true,
        lng: true,
        wardCode: true,
      },
    });
    if (candidates.length === 0) return null;

    let best: RoutedStore | null = null;
    for (const s of candidates) {
      if (s.lat == null || s.lng == null) continue;
      const km = haversineKm(point, { lat: s.lat, lng: s.lng });
      if (best === null || km < best.distanceKm) {
        best = {
          storeId: s.id,
          storeName: s.name,
          storeAddress: s.address,
          distanceKm: km,
          storeWardCode: s.wardCode,
        };
      }
    }
    return best;
  }
}

/// Reused helper so route info can carry the ward back to the caller.
export function summarizeWard(ward: HcmWard) {
  return {
    code: ward.code,
    name: ward.name,
    lat: ward.lat,
    lng: ward.lng,
  };
}

import { BadRequestException } from '@nestjs/common';
import { Role } from '@prisma/client';

import type { AuthPrincipal } from '../auth/types/jwt-payload';

/**
 * Resolves the store scope for a merchant-facing request.
 *   - ADMIN            → `null` (chain-wide; services treat null as global)
 *   - MERCHANT_* w/ store → that storeId
 *   - MERCHANT_* w/o store → 400 NO_STORE_ASSIGNED
 *
 * Centralised so a merchant account missing its `storeId` can never fall
 * through to the `null` (admin/global) branch and read or mutate chain-wide
 * data. Use this everywhere instead of `user.storeId ?? null`.
 */
export function merchantStoreScope(user: AuthPrincipal): string | null {
  if (user.role === Role.ADMIN) return null;
  if (!user.storeId) {
    throw new BadRequestException({
      code: 'NO_STORE_ASSIGNED',
      message: 'Tài khoản chưa được gán cửa hàng.',
    });
  }
  return user.storeId;
}

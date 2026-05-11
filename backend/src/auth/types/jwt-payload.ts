import type { Role } from '@prisma/client';

/**
 * Shape of the JWT access-token payload. `sub` is the user id (RFC 7519).
 * `storeId` / `kitchenId` are present only for staff users and let us
 * scope multi-tenant queries from the JWT alone (never trust request body).
 */
export interface JwtPayload {
  sub: string;
  email: string;
  role: Role;
  storeId?: string | null;
  kitchenId?: string | null;
}

/** Authenticated principal attached to `request.user` by the JWT strategy. */
export interface AuthPrincipal extends JwtPayload {}

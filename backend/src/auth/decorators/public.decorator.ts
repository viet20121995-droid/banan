import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/**
 * Marks a route as public — bypasses the global `JwtAuthGuard`.
 * Use sparingly: only on register / login / refresh / health / webhooks.
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);

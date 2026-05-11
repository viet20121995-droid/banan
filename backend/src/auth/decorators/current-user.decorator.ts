import { ExecutionContext, createParamDecorator } from '@nestjs/common';

import type { AuthPrincipal } from '../types/jwt-payload';

/**
 * Injects the authenticated principal into a controller method.
 * ```ts
 * @Get('me')
 * me(@CurrentUser() user: AuthPrincipal) { ... }
 * ```
 */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthPrincipal => {
    const request = ctx.switchToHttp().getRequest<{ user: AuthPrincipal }>();
    return request.user;
  },
);

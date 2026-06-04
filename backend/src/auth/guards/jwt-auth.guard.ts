import { ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';

import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

/**
 * Global guard. Routes are JWT-protected by default; opt out with `@Public()`.
 * Registered as APP_GUARD in AuthModule.
 */
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private readonly reflector: Reflector) {
    super();
  }

  override canActivate(context: ExecutionContext) {
    // We always run the underlying Passport auth so `req.user` is populated
    // when a Bearer token is present, even on `@Public()` routes. This lets
    // us support "optional auth" endpoints (e.g. guest checkout, where a
    // logged-in customer should still be linked to their account).
    return super.canActivate(context);
  }

  override handleRequest<TUser = unknown>(
    err: unknown,
    user: TUser,
    info: unknown,
    context: ExecutionContext,
  ): TUser {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) {
      // Public routes never throw — `req.user` is `null` when there's no
      // token (or the token is invalid).
      return (user ?? null) as TUser;
    }
    return super.handleRequest(err, user, info, context);
  }
}

import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Role } from '@prisma/client';

import { ROLES_KEY } from '../decorators/roles.decorator';
import type { AuthPrincipal } from '../types/jwt-payload';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<Role[] | undefined>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!required || required.length === 0) return true;

    const request = context.switchToHttp().getRequest<{ user?: AuthPrincipal }>();
    const user = request.user;
    if (!user) {
      throw new ForbiddenException({ code: 'AUTH_FORBIDDEN', message: 'Not authorized' });
    }
    if (!required.includes(user.role)) {
      throw new ForbiddenException({
        code: 'AUTH_FORBIDDEN',
        message: 'Your role cannot perform this action',
      });
    }
    return true;
  }
}

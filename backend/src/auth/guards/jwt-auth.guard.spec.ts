import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { JwtAuthGuard } from './jwt-auth.guard';

const ctx = (url: string) =>
  ({
    getHandler: () => undefined,
    getClass: () => undefined,
    switchToHttp: () => ({ getRequest: () => ({ url }) }),
  }) as unknown as ExecutionContext;

describe('JwtAuthGuard on @Public routes', () => {
  const guard = new JwtAuthGuard({ getAllAndOverride: () => true } as unknown as Reflector);
  const expired = { name: 'TokenExpiredError' };

  it('no token → guest (null user)', () => {
    expect(guard.handleRequest(null, null, undefined, ctx('/api/v1/orders'))).toBeNull();
  });

  it('expired token → 401 so the client refreshes instead of becoming a guest', () => {
    expect(() => guard.handleRequest(null, null, expired, ctx('/api/v1/orders'))).toThrow(
      UnauthorizedException,
    );
  });

  it('expired token on /auth/* (the refresh call itself) still passes', () => {
    expect(guard.handleRequest(null, null, expired, ctx('/api/v1/auth/refresh'))).toBeNull();
  });

  it('malformed token → guest', () => {
    expect(
      guard.handleRequest(null, null, { name: 'JsonWebTokenError' }, ctx('/api/v1/orders')),
    ).toBeNull();
  });
});

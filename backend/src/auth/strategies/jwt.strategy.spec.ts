import { UnauthorizedException } from '@nestjs/common';

import { JwtStrategy } from './jwt.strategy';

/**
 * The JWT strategy re-reads the user on every request so deactivation /
 * role / store changes take effect immediately instead of lingering for the
 * access-token lifetime. These lock that behaviour.
 */
function makeStrategy(user: unknown) {
  const config = {
    get: jest.fn().mockReturnValue('test-secret-at-least-32-characters-long'),
  };
  const findUnique = jest.fn().mockResolvedValue(user);
  const prisma = { user: { findUnique } };
  return {
    strategy: new JwtStrategy(config as never, prisma as never),
    findUnique,
  };
}

const token = {
  sub: 'u1',
  email: 'stale@example.com',
  role: 'CUSTOMER',
} as never;

describe('JwtStrategy.validate', () => {
  it('throws when the user no longer exists', async () => {
    const { strategy } = makeStrategy(null);
    await expect(strategy.validate(token)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('throws when the account has been deactivated', async () => {
    const { strategy } = makeStrategy({
      id: 'u1',
      email: 'a@example.com',
      role: 'MERCHANT_OWNER',
      storeId: 's1',
      kitchenId: null,
      isActive: false,
    });
    await expect(strategy.validate(token)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('returns the FRESH role/store/kitchen from the DB, not the token claims', async () => {
    const { strategy } = makeStrategy({
      id: 'u1',
      email: 'new@example.com',
      role: 'MERCHANT_STAFF',
      storeId: 's2',
      kitchenId: 'k1',
      isActive: true,
    });
    const principal = await strategy.validate(token);
    expect(principal).toEqual({
      sub: 'u1',
      email: 'new@example.com',
      role: 'MERCHANT_STAFF',
      storeId: 's2',
      kitchenId: 'k1',
    });
  });

  it('throws on a payload with no subject', async () => {
    const { strategy } = makeStrategy({ id: 'u1', isActive: true });
    await expect(strategy.validate({} as never)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});

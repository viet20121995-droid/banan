import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

import { PrismaService } from '../../prisma/prisma.service';
import type { AuthPrincipal, JwtPayload } from '../types/jwt-payload';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    const secret = config.get<string>('JWT_ACCESS_SECRET');
    if (!secret) {
      throw new Error('JWT_ACCESS_SECRET is not set');
    }
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: secret,
    });
  }

  /**
   * Whatever this returns becomes `request.user`. We re-read the user from the
   * DB on every request rather than trusting the token's claims, so that
   * deactivating an account or changing its role / store / kitchen takes effect
   * immediately — otherwise a fired or demoted user kept full access (with the
   * old scope every guard reads from `request.user`) until the 15-minute access
   * token expired. The lookup is a primary-key hit, so the cost is negligible.
   */
  async validate(payload: JwtPayload): Promise<AuthPrincipal> {
    if (!payload.sub) {
      throw new UnauthorizedException();
    }
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: {
        id: true,
        email: true,
        role: true,
        storeId: true,
        kitchenId: true,
        isActive: true,
      },
    });
    if (!user || !user.isActive) {
      throw new UnauthorizedException({ code: 'ACCOUNT_INACTIVE' });
    }
    return {
      sub: user.id,
      email: user.email,
      role: user.role,
      storeId: user.storeId,
      kitchenId: user.kitchenId,
    };
  }
}

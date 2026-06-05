import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Prisma, type User } from '@prisma/client';
import bcrypt from 'bcrypt';
import { createHash, randomBytes } from 'node:crypto';

import { EmailService } from '../notifications/email.service';
import { PrismaService } from '../prisma/prisma.service';

import type { LoginDto } from './dto/login.dto';
import type { RegisterDto } from './dto/register.dto';
import type { JwtPayload } from './types/jwt-payload';

interface IssuedTokens {
  accessToken: string;
  refreshToken: string;
  user: User;
}

@Injectable()
export class AuthService {
  private static readonly BCRYPT_ROUNDS = 10;
  private static readonly REFRESH_TTL_DAYS = 30;
  private static readonly RESET_TTL_MINUTES = 60;

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly email: EmailService,
  ) {}

  async register(dto: RegisterDto, deviceId?: string): Promise<IssuedTokens> {
    const passwordHash = await bcrypt.hash(dto.password, AuthService.BCRYPT_ROUNDS);
    try {
      const user = await this.prisma.user.create({
        data: {
          email: dto.email.toLowerCase(),
          phone: dto.phone,
          passwordHash,
          fullName: dto.fullName,
          role: 'CUSTOMER',
          birthday: dto.birthday ? new Date(dto.birthday) : null,
        },
      });
      return this.issueSession(user, deviceId);
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException({
          code: 'AUTH_EMAIL_TAKEN',
          message: 'An account with that email or phone already exists.',
        });
      }
      throw e;
    }
  }

  async login(dto: LoginDto, deviceId?: string): Promise<IssuedTokens> {
    const value = dto.emailOrPhone.toLowerCase();
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ email: value }, { phone: dto.emailOrPhone }] },
    });
    if (!user) throw this.invalidCredentials();

    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) throw this.invalidCredentials();
    if (!user.isActive) throw this.accountDisabled();

    return this.issueSession(user, deviceId);
  }

  /**
   * Validates + rotates a refresh token. The presented token is hashed and
   * looked up; on success we revoke it and issue a fresh pair (rotating
   * refresh tokens). Re-using a revoked token throws — clients must always
   * keep the latest one.
   */
  async refresh(rawToken: string, deviceId?: string): Promise<IssuedTokens> {
    const tokenHash = AuthService.hashToken(rawToken);
    const record = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });
    if (!record || record.revokedAt || record.expiresAt < new Date()) {
      throw new UnauthorizedException({
        code: 'AUTH_REFRESH_INVALID',
        message: 'Refresh token invalid or expired.',
      });
    }
    if (!record.user.isActive) throw this.accountDisabled();
    await this.prisma.refreshToken.update({
      where: { id: record.id },
      data: { revokedAt: new Date() },
    });
    return this.issueSession(record.user, deviceId ?? record.deviceId ?? undefined);
  }

  async logout(rawToken: string): Promise<void> {
    const tokenHash = AuthService.hashToken(rawToken);
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async me(userId: string): Promise<User> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException({ code: 'AUTH_USER_NOT_FOUND' });
    }
    return user;
  }

  /** Self-service profile update. Only the supplied fields change; an empty
   *  phone string clears it. Phone is unique — collisions surface as 409. */
  async updateProfile(
    userId: string,
    dto: {
      fullName?: string;
      phone?: string;
      birthday?: string;
      avatarUrl?: string;
    },
  ): Promise<User> {
    const data: Prisma.UserUpdateInput = {};
    if (dto.fullName !== undefined) data.fullName = dto.fullName.trim();
    if (dto.phone !== undefined) {
      const p = dto.phone.trim();
      data.phone = p.length === 0 ? null : p;
    }
    if (dto.birthday !== undefined) {
      data.birthday = dto.birthday ? new Date(dto.birthday) : null;
    }
    if (dto.avatarUrl !== undefined) {
      const a = dto.avatarUrl.trim();
      data.avatarUrl = a.length === 0 ? null : a;
    }
    try {
      return await this.prisma.user.update({ where: { id: userId }, data });
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        throw new ConflictException({
          code: 'AUTH_PHONE_TAKEN',
          message: 'That phone number is already in use.',
        });
      }
      throw e;
    }
  }

  /**
   * Public wrapper around `issueSession` — lets sibling services (e.g.
   * OrdersService during guest checkout) issue tokens for a user without
   * going through password auth. Use sparingly: the caller is the trust
   * boundary.
   */
  async issueSessionForUser(user: User, deviceId?: string): Promise<IssuedTokens> {
    return this.issueSession(user, deviceId);
  }

  /** Change password for a logged-in user (verifies the current password). */
  async changePassword(
    userId: string,
    currentPassword: string,
    newPassword: string,
  ): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException({ code: 'AUTH_USER_NOT_FOUND' });
    const ok = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException({
        code: 'AUTH_CURRENT_PASSWORD_WRONG',
        message: 'Mật khẩu hiện tại không đúng.',
      });
    }
    const passwordHash = await bcrypt.hash(newPassword, AuthService.BCRYPT_ROUNDS);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash },
    });
  }

  /**
   * Start the forgot-password flow. Always resolves without revealing whether
   * the email exists (anti-enumeration). On a hit, mints a single-use reset
   * token and emails the reset link. The raw token is logged in dry-run mode
   * (no RESEND_API_KEY) so it can still be recovered from server logs.
   */
  async forgotPassword(email: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { email: email.toLowerCase() },
    });
    if (!user || !user.isActive) return;

    // Invalidate any prior unused tokens for this user.
    await this.prisma.passwordReset.updateMany({
      where: { userId: user.id, usedAt: null },
      data: { usedAt: new Date() },
    });

    const rawToken = randomBytes(32).toString('base64url');
    const tokenHash = AuthService.hashToken(rawToken);
    const expiresAt = new Date(
      Date.now() + AuthService.RESET_TTL_MINUTES * 60 * 1000,
    );
    await this.prisma.passwordReset.create({
      data: { userId: user.id, tokenHash, expiresAt },
    });

    const base = (
      this.config.get<string>('CUSTOMER_APP_BASE_URL') ?? 'http://localhost:8081'
    ).replace(/\/$/, '');
    const resetUrl = `${base}/reset-password?token=${rawToken}`;
    await this.email.sendPasswordResetEmail({
      toEmail: user.email,
      toName: user.fullName,
      resetUrl,
    });
  }

  /** Complete the forgot-password flow: validate the token, set the new
   *  password, mark the token used, and revoke all of the user's sessions. */
  async resetPassword(rawToken: string, newPassword: string): Promise<void> {
    const tokenHash = AuthService.hashToken(rawToken);
    const record = await this.prisma.passwordReset.findUnique({
      where: { tokenHash },
    });
    if (!record || record.usedAt || record.expiresAt < new Date()) {
      throw new BadRequestException({
        code: 'AUTH_RESET_INVALID',
        message: 'Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.',
      });
    }
    const passwordHash = await bcrypt.hash(newPassword, AuthService.BCRYPT_ROUNDS);
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: record.userId },
        data: { passwordHash },
      }),
      this.prisma.passwordReset.update({
        where: { id: record.id },
        data: { usedAt: new Date() },
      }),
      this.prisma.refreshToken.updateMany({
        where: { userId: record.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);
  }

  private async issueSession(user: User, deviceId?: string): Promise<IssuedTokens> {
    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      storeId: user.storeId,
      kitchenId: user.kitchenId,
    };

    const accessToken = await this.jwt.signAsync(payload, {
      secret: this.config.get<string>('JWT_ACCESS_SECRET'),
      expiresIn: this.config.get<string>('JWT_ACCESS_TTL') ?? '15m',
    });

    const rawRefresh = randomBytes(48).toString('base64url');
    const tokenHash = AuthService.hashToken(rawRefresh);
    const expiresAt = new Date(
      Date.now() + AuthService.REFRESH_TTL_DAYS * 24 * 60 * 60 * 1000,
    );

    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash,
        deviceId,
        expiresAt,
      },
    });

    return { accessToken, refreshToken: rawRefresh, user };
  }

  private invalidCredentials() {
    return new UnauthorizedException({
      code: 'AUTH_INVALID_CREDENTIALS',
      message: 'Invalid email or password.',
    });
  }

  private accountDisabled() {
    return new UnauthorizedException({
      code: 'AUTH_ACCOUNT_DISABLED',
      message: 'Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.',
    });
  }

  private static hashToken(raw: string): string {
    return createHash('sha256').update(raw).digest('hex');
  }
}

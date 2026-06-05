import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Patch,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { User } from '@prisma/client';

import { CurrentUser } from './decorators/current-user.decorator';
import { Public } from './decorators/public.decorator';
import { ChangePasswordDto } from './dto/change-password.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { RegisterDto } from './dto/register.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { AuthService } from './auth.service';
import type { AuthPrincipal } from './types/jwt-payload';

@ApiTags('auth')
@Controller({ path: 'auth', version: '1' })
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  // Tighter rate limits on credential-handling endpoints — protects against
  // brute-force / enumeration. Defaults (120/min) still apply elsewhere.
  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('register')
  async register(@Body() dto: RegisterDto) {
    const result = await this.auth.register(dto);
    return AuthController.toSession(result);
  }

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @HttpCode(HttpStatus.OK)
  @Post('login')
  async login(@Body() dto: LoginDto) {
    const result = await this.auth.login(dto);
    return AuthController.toSession(result);
  }

  @Public()
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @HttpCode(HttpStatus.OK)
  @Post('refresh')
  async refresh(@Body() dto: RefreshDto) {
    const result = await this.auth.refresh(dto.refreshToken, dto.deviceId);
    return AuthController.toSession(result);
  }

  @HttpCode(HttpStatus.NO_CONTENT)
  @Post('logout')
  async logout(@Body() dto: RefreshDto): Promise<void> {
    await this.auth.logout(dto.refreshToken);
  }

  @ApiBearerAuth()
  @Get('me')
  async me(@CurrentUser() principal: AuthPrincipal) {
    const user = await this.auth.me(principal.sub);
    return { user: AuthController.toUserView(user) };
  }

  @ApiBearerAuth()
  @Patch('me')
  async updateProfile(
    @CurrentUser() principal: AuthPrincipal,
    @Body() dto: UpdateProfileDto,
  ) {
    const user = await this.auth.updateProfile(principal.sub, dto);
    return { user: AuthController.toUserView(user) };
  }

  // ── Password management ───────────────────────────────────────────────────

  @ApiBearerAuth()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @HttpCode(HttpStatus.NO_CONTENT)
  @Post('change-password')
  async changePassword(
    @CurrentUser() principal: AuthPrincipal,
    @Body() dto: ChangePasswordDto,
  ): Promise<void> {
    await this.auth.changePassword(
      principal.sub,
      dto.currentPassword,
      dto.newPassword,
    );
  }

  // Returns 200 with {ok:true} whether or not the email exists — never leak
  // account existence to an unauthenticated caller.
  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @HttpCode(HttpStatus.OK)
  @Post('forgot-password')
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    await this.auth.forgotPassword(dto.email);
    return { ok: true };
  }

  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @HttpCode(HttpStatus.OK)
  @Post('reset-password')
  async resetPassword(@Body() dto: ResetPasswordDto) {
    await this.auth.resetPassword(dto.token, dto.newPassword);
    return { ok: true };
  }

  private static toSession(input: {
    accessToken: string;
    refreshToken: string;
    user: User;
  }) {
    return {
      accessToken: input.accessToken,
      refreshToken: input.refreshToken,
      user: AuthController.toUserView(input.user),
    };
  }

  /** Strips passwordHash and other server-only fields before responding. */
  private static toUserView(user: User) {
    return {
      id: user.id,
      email: user.email,
      phone: user.phone,
      fullName: user.fullName,
      avatarUrl: user.avatarUrl,
      role: user.role,
      membershipTier: user.membershipTier,
      pointsBalance: user.pointsBalance,
      birthday: user.birthday?.toISOString() ?? null,
      storeId: user.storeId,
      kitchenId: user.kitchenId,
    };
  }
}

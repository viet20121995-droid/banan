import { Body, Controller, Get, Param, Patch, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { CurrentUser } from '../../auth/decorators/current-user.decorator';
import { Roles } from '../../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../../auth/types/jwt-payload';

import { UpdateOwnProgressDto } from './dto';
import { TrainingService } from './training.service';

/**
 * Trainee-facing training endpoints — everything here is scoped to the
 * CALLER (person resolved from the JWT's user id, never from a client id),
 * so a trainee can read published materials, see their own path and mark
 * their own progress, and nothing else. Admin management stays on the
 * ADMIN-only TrainingController; QC / MS / schedule controllers remain
 * ADMIN-only and are untouched by this role.
 */
@ApiBearerAuth()
@ApiTags('internal.training.me')
@Controller({ path: 'internal/training/me', version: '1' })
@Roles(Role.ADMIN, Role.TRAINEE)
export class TraineeTrainingController {
  constructor(private readonly training: TrainingService) {}

  /** Own person + own assignments/progress (empty state when not linked). */
  @Get()
  me(@CurrentUser() user: AuthPrincipal) {
    return this.training.meOverview(user.sub);
  }

  /** Published (active) materials only — no `all=true` escape hatch. */
  @Get('materials')
  materials(@Query('category') category?: string) {
    return this.training.listMaterials(category, true);
  }

  /** Status-only update on the caller's OWN progress row. */
  @Patch('progress/:id')
  updateProgress(
    @Param('id') id: string,
    @Body() dto: UpdateOwnProgressDto,
    @CurrentUser() user: AuthPrincipal,
  ) {
    return this.training.updateOwnProgress(id, dto.status, user.sub);
  }
}

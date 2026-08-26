import { Body, Controller, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { CurrentUser } from '../../auth/decorators/current-user.decorator';
import { Roles } from '../../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../../auth/types/jwt-payload';

import {
  AssignPathDto,
  CreateMaterialDto,
  CreatePathDto,
  CreatePersonDto,
  PeopleQueryDto,
  ProgressQueryDto,
  UpdateMaterialDto,
  UpdatePathDto,
  UpdatePersonDto,
  UpdateProgressDto,
} from './dto';
import { TrainingService } from './training.service';

@ApiBearerAuth()
@ApiTags('internal.training')
@Controller({ path: 'internal/training', version: '1' })
@Roles(Role.ADMIN)
export class TrainingController {
  constructor(private readonly training: TrainingService) {}

  // ── people ──
  @Get('people')
  people(@Query() query: PeopleQueryDto) {
    return this.training.listPeople(query);
  }

  @Post('people')
  createPerson(@Body() dto: CreatePersonDto, @CurrentUser() user: AuthPrincipal) {
    return this.training.createPerson(dto, user.sub);
  }

  @Get('people/:id')
  person(@Param('id') id: string) {
    return this.training.personDetail(id);
  }

  @Patch('people/:id')
  updatePerson(
    @Param('id') id: string,
    @Body() dto: UpdatePersonDto,
    @CurrentUser() user: AuthPrincipal,
  ) {
    return this.training.updatePerson(id, dto, user.sub);
  }

  // ── materials ──
  @Get('materials')
  materials(@Query('category') category?: string, @Query('all') all?: string) {
    return this.training.listMaterials(category, all !== 'true');
  }

  @Post('materials')
  createMaterial(@Body() dto: CreateMaterialDto, @CurrentUser() user: AuthPrincipal) {
    return this.training.createMaterial(dto, user.sub);
  }

  @Patch('materials/:id')
  updateMaterial(@Param('id') id: string, @Body() dto: UpdateMaterialDto) {
    return this.training.updateMaterial(id, dto);
  }

  @Post('materials/:id/reissue')
  reissue(
    @Param('id') id: string,
    @Body() dto: CreateMaterialDto,
    @CurrentUser() user: AuthPrincipal,
  ) {
    return this.training.reissueMaterial(id, dto, user.sub);
  }

  // Training PDF uploads moved to the shared PRIVATE store:
  // POST /internal/files/upload-pdf (see InternalFilesController).

  // ── paths ──
  @Get('paths')
  paths() {
    return this.training.listPaths();
  }

  @Post('paths')
  createPath(@Body() dto: CreatePathDto, @CurrentUser() user: AuthPrincipal) {
    return this.training.createPath(dto, user.sub);
  }

  @Patch('paths/:id')
  updatePath(@Param('id') id: string, @Body() dto: UpdatePathDto) {
    return this.training.updatePath(id, dto);
  }

  // ── assignments + progress ──
  @Post('assignments')
  assign(@Body() dto: AssignPathDto, @CurrentUser() user: AuthPrincipal) {
    return this.training.assign(dto, user.sub);
  }

  @Get('progress')
  progress(@Query() query: ProgressQueryDto) {
    return this.training.progressOverview(query);
  }

  @Patch('progress/:id')
  updateProgress(
    @Param('id') id: string,
    @Body() dto: UpdateProgressDto,
    @CurrentUser() user: AuthPrincipal,
  ) {
    return this.training.updateProgress(id, dto, user.sub);
  }
}

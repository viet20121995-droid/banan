import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { CurrentUser } from '../../auth/decorators/current-user.decorator';
import { Roles } from '../../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../../auth/types/jwt-payload';

import {
  CreateAssignmentDto,
  CreateShiftDto,
  CreateWeekDto,
  UpdateAssignmentDto,
  UpdateShiftDto,
  WeeksQueryDto,
} from './dto';
import { ScheduleService } from './schedule.service';

@ApiBearerAuth()
@ApiTags('internal.schedule')
@Controller({ path: 'internal/schedule', version: '1' })
@Roles(Role.ADMIN)
export class ScheduleController {
  constructor(private readonly schedule: ScheduleService) {}

  @Get('weeks')
  weeks(@Query() query: WeeksQueryDto) {
    return this.schedule.listWeeks(query);
  }

  @Get('week')
  week(@Query('weekStart') weekStart: string) {
    return this.schedule.weekByStart(weekStart);
  }

  @Post('weeks')
  createWeek(@Body() dto: CreateWeekDto, @CurrentUser() user: AuthPrincipal) {
    return this.schedule.createWeek(dto, user.sub);
  }

  @Get('weeks/:id')
  detail(@Param('id') id: string) {
    return this.schedule.detail(id);
  }

  @Get('weeks/:id/publishes')
  publishes(@Param('id') id: string) {
    return this.schedule.publishes(id);
  }

  @Post('weeks/:id/publish')
  publish(@Param('id') id: string, @CurrentUser() user: AuthPrincipal) {
    return this.schedule.publish(id, user.sub);
  }

  @Post('weeks/:id/unpublish')
  unpublish(@Param('id') id: string, @CurrentUser() user: AuthPrincipal) {
    return this.schedule.unpublish(id, user.sub);
  }

  @Post('weeks/:id/archive')
  archive(@Param('id') id: string, @CurrentUser() user: AuthPrincipal) {
    return this.schedule.archive(id, user.sub);
  }

  @Post('weeks/:id/shifts')
  addShift(@Param('id') id: string, @Body() dto: CreateShiftDto) {
    return this.schedule.addShift(id, dto);
  }

  @Patch('shifts/:shiftId')
  updateShift(@Param('shiftId') shiftId: string, @Body() dto: UpdateShiftDto) {
    return this.schedule.updateShift(shiftId, dto);
  }

  @Delete('shifts/:shiftId')
  removeShift(@Param('shiftId') shiftId: string) {
    return this.schedule.removeShift(shiftId);
  }

  @Post('shifts/:shiftId/assignments')
  addAssignment(@Param('shiftId') shiftId: string, @Body() dto: CreateAssignmentDto) {
    return this.schedule.addAssignment(shiftId, dto);
  }

  @Patch('assignments/:assignmentId')
  updateAssignment(@Param('assignmentId') assignmentId: string, @Body() dto: UpdateAssignmentDto) {
    return this.schedule.updateAssignment(assignmentId, dto);
  }

  @Delete('assignments/:assignmentId')
  removeAssignment(@Param('assignmentId') assignmentId: string) {
    return this.schedule.removeAssignment(assignmentId);
  }
}

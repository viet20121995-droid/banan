import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';

import type {
  CreateAssignmentDto,
  CreateShiftDto,
  CreateWeekDto,
  UpdateAssignmentDto,
  UpdateShiftDto,
  WeeksQueryDto,
} from './dto';
import { computeScheduleWarnings, type WarnShift } from './schedule-warnings';

/** Editable default shifts pre-filled into every new week for every store. */
export const DEFAULT_SHIFTS: { label: string; startTime: string; endTime: string }[] = [
  { label: 'Ca 1', startTime: '09:00', endTime: '14:00' },
  { label: 'Ca 2', startTime: '14:00', endTime: '18:00' },
  { label: 'Ca 3', startTime: '18:00', endTime: '22:00' },
];

const SCHEDULE_INCLUDE = {
  shifts: {
    orderBy: [{ storeId: 'asc' as const }, { sortOrder: 'asc' as const }],
    include: {
      store: { select: { id: true, name: true } },
      assignments: {
        orderBy: [{ dayOfWeek: 'asc' as const }, { sortOrder: 'asc' as const }],
        include: { person: { select: { id: true, fullName: true, isActive: true } } },
      },
    },
  },
};

type ScheduleWithShifts = Prisma.WorkScheduleGetPayload<{ include: typeof SCHEDULE_INCLUDE }>;

/** Snaps any date to the Monday 00:00 UTC of its (VN) week. */
export function mondayOf(dateIso: string): Date {
  const d = new Date(dateIso);
  const vn = new Date(d.getTime() + 7 * 3600_000);
  const dow = (vn.getUTCDay() + 6) % 7; // Mon=0
  vn.setUTCHours(0, 0, 0, 0);
  return new Date(vn.getTime() - dow * 86_400_000 - 7 * 3600_000);
}

@Injectable()
export class ScheduleService {
  constructor(private readonly prisma: PrismaService) {}

  async listWeeks(query: WeeksQueryDto, limit = 12) {
    const weeks = await this.prisma.workSchedule.findMany({
      where: { ...(query.status && { status: query.status as never }) },
      orderBy: { weekStart: 'desc' },
      take: limit,
      select: {
        id: true,
        weekStart: true,
        status: true,
        revision: true,
        publishedAt: true,
        updatedAt: true,
      },
    });
    return weeks.map((w) => ({ ...w, weekStart: w.weekStart.toISOString() }));
  }

  async weekByStart(weekStartIso: string) {
    const schedule = await this.prisma.workSchedule.findUnique({
      where: { weekStart: mondayOf(weekStartIso) },
      include: SCHEDULE_INCLUDE,
    });
    return schedule ? this.toView(schedule) : null;
  }

  async createWeek(dto: CreateWeekDto, actorId: string) {
    const weekStart = mondayOf(dto.weekStart);
    const existing = await this.prisma.workSchedule.findUnique({ where: { weekStart } });
    if (existing) {
      throw new BadRequestException({
        code: 'INTERNAL_SCHEDULE_WEEK_EXISTS',
        message: 'Tuần này đã có lịch.',
      });
    }
    let source: ScheduleWithShifts | null = null;
    if (dto.copyFromScheduleId) {
      source = await this.prisma.workSchedule.findUnique({
        where: { id: dto.copyFromScheduleId },
        include: SCHEDULE_INCLUDE,
      });
      if (!source) {
        throw new BadRequestException({
          code: 'INTERNAL_SCHEDULE_SOURCE_NOT_FOUND',
          message: 'Không tìm thấy tuần nguồn để sao chép.',
        });
      }
    }
    const stores = await this.prisma.store.findMany({
      select: { id: true },
      orderBy: { createdAt: 'asc' },
    });

    // Copy never mutates the source — a fresh tree is written for the new
    // week; the source keeps its own rows untouched.
    const schedule = await this.prisma.workSchedule.create({
      data: {
        weekStart,
        createdById: actorId,
        shifts: {
          create: source
            ? source.shifts.map((s) => ({
                storeId: s.storeId,
                label: s.label,
                startTime: s.startTime,
                endTime: s.endTime,
                sortOrder: s.sortOrder,
                assignments: {
                  create: s.assignments.map((a) => ({
                    dayOfWeek: a.dayOfWeek,
                    personId: a.personId,
                    freeName: a.freeName,
                    note: a.note,
                    sortOrder: a.sortOrder,
                  })),
                },
              }))
            : stores.flatMap((store) =>
                DEFAULT_SHIFTS.map((s, idx) => ({
                  storeId: store.id,
                  label: s.label,
                  startTime: s.startTime,
                  endTime: s.endTime,
                  sortOrder: idx,
                })),
              ),
        },
      },
      include: SCHEDULE_INCLUDE,
    });
    return this.toView(schedule);
  }

  async addShift(scheduleId: string, dto: CreateShiftDto) {
    const schedule = await this.editable(scheduleId);
    const store = await this.prisma.store.findUnique({ where: { id: dto.storeId } });
    if (!store) {
      throw new BadRequestException({
        code: 'INTERNAL_SCHEDULE_STORE_NOT_FOUND',
        message: 'Chi nhánh không tồn tại.',
      });
    }
    const max = await this.prisma.workScheduleShift.aggregate({
      where: { scheduleId, storeId: dto.storeId },
      _max: { sortOrder: true },
    });
    await this.prisma.workScheduleShift.create({
      data: {
        scheduleId,
        storeId: dto.storeId,
        label: dto.label.trim(),
        startTime: dto.startTime,
        endTime: dto.endTime,
        sortOrder: (max._max.sortOrder ?? -1) + 1,
      },
    });
    return this.detail(schedule.id);
  }

  async updateShift(shiftId: string, dto: UpdateShiftDto) {
    const shift = await this.shiftById(shiftId);
    await this.editable(shift.scheduleId);
    await this.prisma.workScheduleShift.update({
      where: { id: shiftId },
      data: {
        ...(dto.label !== undefined && { label: dto.label.trim() }),
        ...(dto.startTime !== undefined && { startTime: dto.startTime }),
        ...(dto.endTime !== undefined && { endTime: dto.endTime }),
      },
    });
    return this.detail(shift.scheduleId);
  }

  async removeShift(shiftId: string) {
    const shift = await this.shiftById(shiftId);
    await this.editable(shift.scheduleId);
    await this.prisma.workScheduleShift.delete({ where: { id: shiftId } });
    return this.detail(shift.scheduleId);
  }

  async addAssignment(shiftId: string, dto: CreateAssignmentDto) {
    const shift = await this.shiftById(shiftId);
    await this.editable(shift.scheduleId);
    if (!dto.personId && !dto.freeName?.trim()) {
      throw new BadRequestException({
        code: 'INTERNAL_SCHEDULE_WHO',
        message: 'Chọn nhân sự hoặc nhập tên.',
      });
    }
    if (dto.personId) {
      const person = await this.prisma.internalPerson.findUnique({ where: { id: dto.personId } });
      if (!person) {
        throw new BadRequestException({
          code: 'INTERNAL_SCHEDULE_PERSON_NOT_FOUND',
          message: 'Nhân sự không tồn tại.',
        });
      }
    }
    const max = await this.prisma.workScheduleAssignment.aggregate({
      where: { shiftId, dayOfWeek: dto.dayOfWeek },
      _max: { sortOrder: true },
    });
    await this.prisma.workScheduleAssignment.create({
      data: {
        shiftId,
        dayOfWeek: dto.dayOfWeek,
        personId: dto.personId ?? null,
        freeName: dto.personId ? null : (dto.freeName?.trim() ?? null),
        note: dto.note?.trim() || null,
        sortOrder: (max._max.sortOrder ?? -1) + 1,
      },
    });
    return this.detail(shift.scheduleId);
  }

  async updateAssignment(assignmentId: string, dto: UpdateAssignmentDto) {
    const assignment = await this.prisma.workScheduleAssignment.findUnique({
      where: { id: assignmentId },
      include: { shift: { select: { scheduleId: true } } },
    });
    if (!assignment) this.notFound();
    await this.editable(assignment.shift.scheduleId);
    await this.prisma.workScheduleAssignment.update({
      where: { id: assignmentId },
      data: {
        ...(dto.dayOfWeek !== undefined && { dayOfWeek: dto.dayOfWeek }),
        ...(dto.personId !== undefined && {
          personId: dto.personId,
          ...(dto.personId != null && { freeName: null }),
        }),
        ...(dto.freeName !== undefined && {
          freeName: dto.freeName?.trim() || null,
          ...(dto.freeName?.trim() && { personId: null }),
        }),
        ...(dto.note !== undefined && { note: dto.note?.trim() || null }),
      },
    });
    return this.detail(assignment.shift.scheduleId);
  }

  async removeAssignment(assignmentId: string) {
    const assignment = await this.prisma.workScheduleAssignment.findUnique({
      where: { id: assignmentId },
      include: { shift: { select: { scheduleId: true } } },
    });
    if (!assignment) this.notFound();
    await this.editable(assignment.shift.scheduleId);
    await this.prisma.workScheduleAssignment.delete({ where: { id: assignmentId } });
    return this.detail(assignment.shift.scheduleId);
  }

  /**
   * Publishes the week: bumps the revision and freezes a full snapshot.
   * Revision-CAS + the unique (scheduleId, revision) on the snapshot mean
   * two parallel publishes can only ever produce one new revision.
   */
  async publish(scheduleId: string, actorId: string) {
    const schedule = await this.prisma.workSchedule.findUnique({
      where: { id: scheduleId },
      include: SCHEDULE_INCLUDE,
    });
    if (!schedule) this.notFound();
    if (schedule.status === 'ARCHIVED') {
      throw new BadRequestException({
        code: 'INTERNAL_SCHEDULE_ARCHIVED',
        message: 'Tuần đã lưu trữ.',
      });
    }
    const snapshot = this.toView(schedule);
    await this.prisma.$transaction(async (tx) => {
      const claimed = await tx.workSchedule.updateMany({
        where: { id: scheduleId, revision: schedule.revision },
        data: {
          status: 'PUBLISHED',
          revision: schedule.revision + 1,
          publishedAt: new Date(),
          publishedById: actorId,
        },
      });
      if (claimed.count === 0) {
        throw new BadRequestException({
          code: 'INTERNAL_SCHEDULE_PUBLISH_RACE',
          message: 'Lịch vừa được thao tác ở nơi khác — tải lại rồi thử lại.',
        });
      }
      await tx.workSchedulePublish.create({
        data: {
          scheduleId,
          revision: schedule.revision + 1,
          snapshot: snapshot as unknown as Prisma.InputJsonValue,
          publishedById: actorId,
        },
      });
    });
    return this.detail(scheduleId);
  }

  async unpublish(scheduleId: string, actorId: string) {
    const claimed = await this.prisma.workSchedule.updateMany({
      where: { id: scheduleId, status: 'PUBLISHED' },
      data: { status: 'DRAFT', updatedById: actorId },
    });
    if (claimed.count === 0) {
      throw new BadRequestException({
        code: 'INTERNAL_SCHEDULE_NOT_PUBLISHED',
        message: 'Tuần chưa publish.',
      });
    }
    return this.detail(scheduleId);
  }

  async archive(scheduleId: string, actorId: string) {
    await this.prisma.workSchedule.update({
      where: { id: scheduleId },
      data: { status: 'ARCHIVED', updatedById: actorId },
    });
    return this.detail(scheduleId);
  }

  async detail(scheduleId: string) {
    const schedule = await this.prisma.workSchedule.findUnique({
      where: { id: scheduleId },
      include: SCHEDULE_INCLUDE,
    });
    if (!schedule) this.notFound();
    return this.toView(schedule);
  }

  async publishes(scheduleId: string) {
    const rows = await this.prisma.workSchedulePublish.findMany({
      where: { scheduleId },
      orderBy: { revision: 'desc' },
      select: { revision: true, publishedAt: true, publishedById: true },
    });
    return rows.map((r) => ({ ...r, publishedAt: r.publishedAt.toISOString() }));
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  private toView(schedule: ScheduleWithShifts) {
    const warnShifts: WarnShift[] = schedule.shifts.map((s) => ({
      id: s.id,
      storeId: s.storeId,
      storeName: s.store.name,
      label: s.label,
      startTime: s.startTime,
      endTime: s.endTime,
      assignments: s.assignments.map((a) => ({
        id: a.id,
        dayOfWeek: a.dayOfWeek,
        personId: a.personId,
        personName: a.person?.fullName ?? null,
        personActive: a.person?.isActive ?? null,
        freeName: a.freeName,
      })),
    }));
    return {
      id: schedule.id,
      weekStart: schedule.weekStart.toISOString(),
      status: schedule.status,
      revision: schedule.revision,
      publishedAt: schedule.publishedAt?.toISOString() ?? null,
      notes: schedule.notes,
      shifts: schedule.shifts.map((s) => ({
        id: s.id,
        store: s.store,
        label: s.label,
        startTime: s.startTime,
        endTime: s.endTime,
        sortOrder: s.sortOrder,
        assignments: s.assignments.map((a) => ({
          id: a.id,
          dayOfWeek: a.dayOfWeek,
          personId: a.personId,
          personName: a.person?.fullName ?? null,
          personActive: a.person?.isActive ?? null,
          freeName: a.freeName,
          note: a.note,
        })),
      })),
      warnings: computeScheduleWarnings(warnShifts),
    };
  }

  private async editable(scheduleId: string) {
    const schedule = await this.prisma.workSchedule.findUnique({
      where: { id: scheduleId },
      select: { id: true, status: true },
    });
    if (!schedule) this.notFound();
    if (schedule.status === 'ARCHIVED') {
      throw new BadRequestException({
        code: 'INTERNAL_SCHEDULE_ARCHIVED',
        message: 'Tuần đã lưu trữ — không sửa được.',
      });
    }
    return schedule;
  }

  private async shiftById(shiftId: string) {
    const shift = await this.prisma.workScheduleShift.findUnique({
      where: { id: shiftId },
      select: { id: true, scheduleId: true },
    });
    if (!shift) this.notFound();
    return shift;
  }

  private notFound(): never {
    throw new NotFoundException({
      code: 'INTERNAL_SCHEDULE_NOT_FOUND',
      message: 'Không tìm thấy lịch.',
    });
  }
}

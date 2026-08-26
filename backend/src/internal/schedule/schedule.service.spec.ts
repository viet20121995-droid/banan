import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';

import { ROLES_KEY } from '../../auth/decorators/roles.decorator';

import { ScheduleController } from './schedule.controller';
import { ScheduleService, mondayOf } from './schedule.service';

function scheduleFixture(revision = 3) {
  return {
    id: 'w1',
    weekStart: new Date('2026-08-17T00:00:00Z'),
    status: 'DRAFT',
    revision,
    notes: null,
    publishedAt: null,
    shifts: [
      {
        id: 'sh1',
        storeId: 's1',
        store: { id: 's1', name: 'Banan LTT' },
        label: 'Ca 1',
        startTime: '09:00',
        endTime: '14:00',
        sortOrder: 0,
        assignments: [
          {
            id: 'a1',
            dayOfWeek: 0,
            personId: null,
            person: null,
            freeName: 'Phương',
            note: 'đến 16h',
            sortOrder: 0,
          },
        ],
      },
    ],
  };
}

function makeService(opts: { claimCount?: number } = {}) {
  const schedule = scheduleFixture();
  const scheduleUpdateMany = jest.fn().mockResolvedValue({ count: opts.claimCount ?? 1 });
  const publishCreate = jest.fn().mockResolvedValue({});
  const scheduleCreate = jest.fn().mockResolvedValue(schedule);
  const tx = {
    workSchedule: { updateMany: scheduleUpdateMany },
    workSchedulePublish: { create: publishCreate },
  };
  const prisma = {
    workSchedule: {
      findUnique: jest.fn().mockResolvedValue(schedule),
      create: scheduleCreate,
      update: jest.fn(),
      updateMany: scheduleUpdateMany,
    },
    workScheduleShift: {
      update: jest.fn(),
      findUnique: jest.fn().mockResolvedValue({ id: 'sh1', scheduleId: 'w1' }),
      aggregate: jest.fn().mockResolvedValue({ _max: { sortOrder: 0 } }),
    },
    workScheduleAssignment: {
      create: jest.fn().mockResolvedValue({}),
      aggregate: jest.fn().mockResolvedValue({ _max: { sortOrder: 0 } }),
    },
    store: {
      findMany: jest
        .fn()
        .mockResolvedValue([{ id: 's1' }, { id: 's2' }, { id: 's3' }, { id: 's4' }]),
      findUnique: jest.fn().mockResolvedValue({ id: 's1' }),
    },
    internalPerson: { findUnique: jest.fn().mockResolvedValue({ id: 'p1' }) },
    $transaction: jest.fn((fn: (t: unknown) => Promise<unknown>) => fn(tx)),
  };
  const svc = new ScheduleService(prisma as never);
  return { svc, prisma, tx, scheduleUpdateMany, publishCreate, scheduleCreate, schedule };
}

describe('mondayOf', () => {
  it('snaps any VN day to its Monday', () => {
    // 2026-08-20 is a Thursday (VN) → Monday is 2026-08-17.
    expect(mondayOf('2026-08-20').toISOString()).toBe('2026-08-16T17:00:00.000Z');
    expect(mondayOf('2026-08-17').toISOString()).toBe('2026-08-16T17:00:00.000Z');
  });
});

describe('ScheduleService.createWeek copy', () => {
  it('copying a week writes a NEW tree and never mutates the source', async () => {
    const m = makeService();
    // First findUnique: target week (must not exist) → null; second: source.
    m.prisma.workSchedule.findUnique = jest
      .fn()
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(m.schedule);
    await m.svc.createWeek({ weekStart: '2026-08-24', copyFromScheduleId: 'w1' }, 'admin');

    const createArg = m.scheduleCreate.mock.calls[0][0].data;
    expect(createArg.shifts.create[0].assignments.create[0].freeName).toBe('Phương');
    // Source untouched: no update/updateMany fired by the copy.
    expect(m.prisma.workSchedule.update).not.toHaveBeenCalled();
    expect(m.scheduleUpdateMany).not.toHaveBeenCalled();
  });

  it('a week that already exists is refused', async () => {
    const m = makeService();
    await expect(m.svc.createWeek({ weekStart: '2026-08-17' }, 'admin')).rejects.toMatchObject({
      response: { code: 'INTERNAL_SCHEDULE_WEEK_EXISTS' },
    });
  });
});

describe('ScheduleService.publish', () => {
  it('bumps the revision and snapshots it (revision-CAS + unique)', async () => {
    const m = makeService();
    await m.svc.publish('w1', 'admin');
    expect(m.scheduleUpdateMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 'w1', revision: 3 } }),
    );
    expect(m.publishCreate.mock.calls[0][0].data.revision).toBe(4);
  });

  it('two parallel publishes: the loser (count 0) errors and writes NO snapshot', async () => {
    const m = makeService({ claimCount: 0 });
    await expect(m.svc.publish('w1', 'admin')).rejects.toMatchObject({
      response: { code: 'INTERNAL_SCHEDULE_PUBLISH_RACE' },
    });
    expect(m.publishCreate).not.toHaveBeenCalled();
  });
});

describe('ScheduleService.addAssignment', () => {
  it('free-text names are accepted', async () => {
    const m = makeService();
    m.prisma.workScheduleShift.findUnique = jest
      .fn()
      .mockResolvedValue({ id: 'sh1', scheduleId: 'w1' });
    await m.svc.addAssignment('sh1', { dayOfWeek: 2, freeName: 'Cô Hoa' });
    expect(m.prisma.workScheduleAssignment.create.mock.calls[0][0].data.freeName).toBe('Cô Hoa');
  });

  it('neither person nor name → refused', async () => {
    const m = makeService();
    m.prisma.workScheduleShift.findUnique = jest
      .fn()
      .mockResolvedValue({ id: 'sh1', scheduleId: 'w1' });
    await expect(m.svc.addAssignment('sh1', { dayOfWeek: 2 })).rejects.toMatchObject({
      response: { code: 'INTERNAL_SCHEDULE_WHO' },
    });
  });
});

describe('ScheduleController authorization metadata', () => {
  it('gated to ADMIN only', () => {
    const roles = new Reflector().get<Role[]>(ROLES_KEY, ScheduleController);
    expect(roles).toEqual([Role.ADMIN]);
  });
});

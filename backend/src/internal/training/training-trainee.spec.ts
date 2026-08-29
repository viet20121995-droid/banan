import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';

import { ROLES_KEY } from '../../auth/decorators/roles.decorator';
import { InternalFilesController } from '../files/internal-files.controller';
import { MsController } from '../ms/ms.controller';
import { QcController } from '../qc/qc.controller';
import { ScheduleController } from '../schedule/schedule.controller';

import { TraineeTrainingController } from './trainee-training.controller';
import { TrainingController } from './training.controller';
import { TrainingService } from './training.service';

const reflector = new Reflector();

describe('role surface (metadata) — TRAINEE stays out of admin areas', () => {
  it('trainee controller admits ADMIN + TRAINEE', () => {
    expect(reflector.get<Role[]>(ROLES_KEY, TraineeTrainingController)).toEqual([
      Role.ADMIN,
      Role.TRAINEE,
    ]);
  });

  it.each([
    ['TrainingController (management)', TrainingController],
    ['QcController', QcController],
    ['MsController', MsController],
    ['ScheduleController', ScheduleController],
    ['InternalFilesController (uploads)', InternalFilesController],
  ])('%s stays ADMIN-only at class level', (_label, ctrl) => {
    expect(reflector.get<Role[]>(ROLES_KEY, ctrl)).toEqual([Role.ADMIN]);
  });

  it('private-file READ additionally admits TRAINEE (training FILEs only)', () => {
    expect(reflector.get<Role[]>(ROLES_KEY, InternalFilesController.prototype.read)).toEqual([
      Role.ADMIN,
      Role.TRAINEE,
    ]);
  });
});

function makeService(
  opts: { person?: object | null; ownProgress?: boolean; claimCount?: number } = {},
) {
  const own = opts.ownProgress ?? true;
  // The guarded write claims 1 row unless the test says otherwise (already
  // confirmed, or not the caller's row).
  const progressClaim = jest.fn().mockResolvedValue({ count: opts.claimCount ?? (own ? 1 : 0) });
  const prisma = {
    internalPerson: {
      findUnique: jest.fn().mockResolvedValue(
        opts.person === null
          ? null
          : (opts.person ?? {
              id: 'person1',
              fullName: 'Trainee',
              position: 'Trainee',
              store: { id: 's1', name: 'LTT' },
            }),
      ),
    },
    trainingAssignment: { findMany: jest.fn().mockResolvedValue([]) },
    trainingProgress: {
      updateMany: progressClaim,
      findFirst: jest.fn().mockResolvedValue(own ? { status: 'COMPLETED' } : null),
      findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'p1', status: 'PENDING_CONFIRMATION' }),
    },
  };
  return { svc: new TrainingService(prisma as never), prisma, progressClaim };
}

describe('TrainingService trainee self-service', () => {
  it('meOverview without a linked person is an explicit empty state, not an error', async () => {
    const m = makeService({ person: null });
    await expect(m.svc.meOverview('u1')).resolves.toEqual({ person: null, assignments: [] });
  });

  it('meOverview resolves the person from the JWT user id, never a client id', async () => {
    const m = makeService();
    const res = await m.svc.meOverview('u1');
    expect(m.prisma.internalPerson.findUnique).toHaveBeenCalledWith(
      expect.objectContaining({ where: { userId: 'u1' } }),
    );
    expect(res.person).toMatchObject({ fullName: 'Trainee' });
    // Own assignments only — scoped by the resolved personId.
    expect(m.prisma.trainingAssignment.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { personId: 'person1' } }),
    );
  });

  it("updateOwnProgress on someone else's row 404s (IDOR) — write matched nothing", async () => {
    const m = makeService({ ownProgress: false });
    await expect(
      m.svc.updateOwnProgress('foreign-progress', 'COMPLETED', 'u1'),
    ).rejects.toMatchObject({ response: { code: 'INTERNAL_TRAINING_PROGRESS_NOT_FOUND' } });
    // Ownership travels INSIDE the guarded write itself.
    expect(m.progressClaim).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id: 'foreign-progress',
          status: { not: 'COMPLETED' },
          assignment: { person: { userId: 'u1' } },
        },
      }),
    );
  });

  it('trainee "COMPLETED" lands as PENDING_CONFIRMATION via ONE guarded write', async () => {
    const m = makeService();
    await m.svc.updateOwnProgress('p1', 'COMPLETED', 'u1');
    const call = m.progressClaim.mock.calls[0][0];
    // Atomic: ownership + not-yet-confirmed in the SAME statement — an admin
    // COMPLETED landing in between can never be wiped back (the race fix).
    expect(call.where.status).toEqual({ not: 'COMPLETED' });
    expect(call.data.status).toBe('PENDING_CONFIRMATION');
    expect(call.data.completedAt).toBeNull();
    expect(call.data.confirmedById).toBeNull();
  });

  it('an admin-CONFIRMED row cannot be re-flagged by the trainee', async () => {
    const m = makeService({ claimCount: 0 });
    await expect(m.svc.updateOwnProgress('p1', 'IN_PROGRESS', 'u1')).rejects.toMatchObject({
      response: { code: 'INTERNAL_TRAINING_ALREADY_CONFIRMED' },
    });
  });

  it('admin confirmation (updateProgress COMPLETED) still stamps completedAt + admin id', async () => {
    const m = makeService();
    const adminUpdate = jest.fn().mockResolvedValue({ id: 'p1' });
    (m.prisma.trainingProgress as Record<string, unknown>).findUnique = jest
      .fn()
      .mockResolvedValue({ id: 'p1' });
    (m.prisma.trainingProgress as Record<string, unknown>).update = adminUpdate;
    await m.svc.updateProgress('p1', { status: 'COMPLETED' } as never, 'admin-1');
    const data = adminUpdate.mock.calls[0][0].data;
    expect(data.status).toBe('COMPLETED');
    expect(data.completedAt).toBeInstanceOf(Date);
    expect(data.confirmedById).toBe('admin-1');
  });
});

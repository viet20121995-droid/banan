import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';

import { ROLES_KEY } from '../../auth/decorators/roles.decorator';

import { TrainingController } from './training.controller';
import { TrainingService } from './training.service';

describe('TrainingService.reissueMaterial', () => {
  it('keeps the old version row (deactivated) and links the new one', async () => {
    const old = { id: 'm1', version: 2, isRequired: true, estimatedMinutes: 30 };
    const materialUpdate = jest.fn().mockReturnValue('UPDATE_OP');
    const materialCreate = jest.fn().mockReturnValue('CREATE_OP');
    const prisma = {
      trainingMaterial: {
        findUnique: jest.fn().mockResolvedValue(old),
        update: materialUpdate,
        create: materialCreate,
      },
      $transaction: jest.fn().mockResolvedValue(['old-updated', { id: 'm2', version: 3 }]),
    };
    const svc = new TrainingService(prisma as never);
    const fresh = await svc.reissueMaterial(
      'm1',
      { title: 'V3', category: 'PHA_CHE', kind: 'LINK', url: 'https://youtu.be/x' },
      'admin',
    );
    expect(fresh).toEqual({ id: 'm2', version: 3 });
    // Old row: deactivate only — never deleted, never overwritten.
    expect(materialUpdate).toHaveBeenCalledWith({
      where: { id: 'm1' },
      data: { isActive: false },
    });
    const createData = materialCreate.mock.calls[0][0].data;
    expect(createData.version).toBe(3);
    expect(createData.supersedesId).toBe('m1');
  });
});

describe('TrainingService progress deadlines', () => {
  function overview(startDaysAgo: number, dueDays: number | null, status = 'NOT_STARTED') {
    const startDate = new Date(Date.now() - startDaysAgo * 86_400_000);
    const prisma = {
      trainingAssignment: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'as1',
            personId: 'p1',
            startDate,
            person: {
              id: 'p1',
              fullName: 'A',
              isActive: true,
              store: { id: 's1', name: 'LTT' },
            },
            path: { id: 'path1', name: 'Onboard' },
            progress: [
              {
                id: 'pr1',
                status,
                completedAt: null,
                quizScore: null,
                attempts: 0,
                notes: null,
                pathItem: {
                  id: 'pi1',
                  sortOrder: 0,
                  isRequired: true,
                  dueDays,
                  material: {
                    id: 'm1',
                    title: 'B1',
                    category: 'ATVSTP',
                    kind: 'LINK',
                    url: null,
                    version: 1,
                  },
                },
              },
            ],
          },
        ]),
      },
    };
    return new TrainingService(prisma as never).progressOverview({});
  }

  it('past-due incomplete item derives EXPIRED + overdue flag', async () => {
    const rows = await overview(10, 7);
    expect(rows[0].progress[0].overdue).toBe(true);
    expect(rows[0].progress[0].effectiveStatus).toBe('EXPIRED');
    expect(rows[0].overdueCount).toBe(1);
    expect(rows[0].percentDone).toBe(0);
  });

  it('completed or within-deadline items are not overdue', async () => {
    const done = await overview(10, 7, 'COMPLETED');
    expect(done[0].progress[0].overdue).toBe(false);
    expect(done[0].percentDone).toBe(100);
    const inTime = await overview(3, 7);
    expect(inTime[0].progress[0].overdue).toBe(false);
    const noDeadline = await overview(100, null);
    expect(noDeadline[0].progress[0].overdue).toBe(false);
  });
});

describe('TrainingService.updatePerson transfer history', () => {
  it('a store change appends a transfer row with from/to', async () => {
    const transferCreate = jest.fn().mockResolvedValue({});
    const prisma = {
      internalPerson: {
        findUnique: jest.fn().mockResolvedValue({ id: 'p1', storeId: 'A' }),
        update: jest.fn().mockResolvedValue({}),
      },
      internalPersonTransfer: { create: transferCreate },
      store: { findUnique: jest.fn().mockResolvedValue({ id: 'B' }) },
    };
    const svc = new TrainingService(prisma as never);
    await svc.updatePerson('p1', { storeId: 'B' }, 'admin');
    expect(transferCreate).toHaveBeenCalledWith({
      data: { personId: 'p1', fromStoreId: 'A', toStoreId: 'B', changedById: 'admin' },
    });
  });
});

describe('TrainingController authorization metadata', () => {
  it('gated to ADMIN only', () => {
    const roles = new Reflector().get<Role[]>(ROLES_KEY, TrainingController);
    expect(roles).toEqual([Role.ADMIN]);
  });
});

import { seedTraineeAccount } from './internal-seed';

function makePrisma(state: {
  user?: { id: string; role?: string; isActive?: boolean } | null;
  person?: object | null;
}) {
  const userCreate = jest.fn().mockResolvedValue({ id: 'u-trainee' });
  const userUpdate = jest.fn().mockResolvedValue({});
  const personCreate = jest.fn().mockResolvedValue({ id: 'p-trainee' });
  const prisma = {
    user: {
      findUnique: jest
        .fn()
        .mockResolvedValue(state.user ? { role: 'TRAINEE', isActive: true, ...state.user } : null),
      create: userCreate,
      update: userUpdate,
    },
    internalPerson: {
      findUnique: jest.fn().mockResolvedValue(state.person ?? null),
      create: personCreate,
    },
    store: { findFirst: jest.fn().mockResolvedValue({ id: 's1' }) },
  };
  return { prisma, userCreate, userUpdate, personCreate };
}

describe('seedTraineeAccount (idempotent)', () => {
  it('first run creates the TRAINEE user + linked InternalPerson', async () => {
    const m = makePrisma({});
    await seedTraineeAccount(m.prisma as never);

    expect(m.userCreate).toHaveBeenCalledTimes(1);
    const user = m.userCreate.mock.calls[0][0].data;
    expect(user.email).toBe('trainee@banan.local');
    expect(user.role).toBe('TRAINEE');
    expect(user.isActive).toBe(true);
    expect(user.fullName).toBe('Trainee');
    // bcrypt hash — NEVER the plaintext password in the row.
    expect(user.passwordHash).toMatch(/^\$2[aby]\$/);
    expect(user.passwordHash).not.toContain('Vietnam123');

    expect(m.personCreate).toHaveBeenCalledTimes(1);
    expect(m.personCreate.mock.calls[0][0].data).toMatchObject({
      fullName: 'Trainee',
      userId: 'u-trainee',
      storeId: 's1',
    });
  });

  it('second run (user + person already there) creates NOTHING and resets nothing', async () => {
    const m = makePrisma({ user: { id: 'u-trainee' }, person: { id: 'p-trainee' } });
    await seedTraineeAccount(m.prisma as never);
    expect(m.userCreate).not.toHaveBeenCalled();
    expect(m.personCreate).not.toHaveBeenCalled();
  });

  it('missing store skips the person link gracefully (re-run later completes it)', async () => {
    const m = makePrisma({ user: { id: 'u-trainee' } });
    m.prisma.store.findFirst.mockResolvedValue(null as never);
    await expect(seedTraineeAccount(m.prisma as never)).resolves.toBeUndefined();
    expect(m.personCreate).not.toHaveBeenCalled();
  });

  it('email owned by a DIFFERENT role fails LOUDLY — never converted, never linked', async () => {
    const m = makePrisma({ user: { id: 'u-x', role: 'ADMIN' } });
    await expect(seedTraineeAccount(m.prisma as never)).rejects.toThrow(/role ADMIN/);
    expect(m.userCreate).not.toHaveBeenCalled();
    expect(m.userUpdate).not.toHaveBeenCalled();
    expect(m.personCreate).not.toHaveBeenCalled();
  });

  it('a deactivated TRAINEE is deliberately re-activated — password untouched', async () => {
    const m = makePrisma({
      user: { id: 'u-trainee', isActive: false },
      person: { id: 'p-trainee' },
    });
    await seedTraineeAccount(m.prisma as never);
    expect(m.userUpdate).toHaveBeenCalledWith({
      where: { id: 'u-trainee' },
      data: { isActive: true },
    });
    // Never a passwordHash write on an existing account.
    expect(JSON.stringify(m.userUpdate.mock.calls)).not.toContain('passwordHash');
    expect(m.userCreate).not.toHaveBeenCalled();
  });
});

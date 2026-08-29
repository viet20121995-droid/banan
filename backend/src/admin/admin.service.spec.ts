import { AdminService } from './admin.service';
import { ProvisionableRole } from './dto/create-user.dto';

function makeService(opts: { person?: { userId: string | null } | null; linkCount?: number } = {}) {
  const userCreate = jest.fn().mockResolvedValue({
    id: 'u-new',
    email: 'trainee2@banan.local',
    fullName: 'Trainee 2',
    role: 'TRAINEE',
    isActive: true,
    createdAt: new Date(),
  });
  const personLink = jest.fn().mockResolvedValue({ count: opts.linkCount ?? 1 });
  const tx = { user: { create: userCreate }, internalPerson: { updateMany: personLink } };
  const prisma = {
    internalPerson: {
      findUnique: jest
        .fn()
        .mockResolvedValue(
          opts.person === null ? null : (opts.person ?? { id: 'person1', userId: null }),
        ),
    },
    $transaction: jest.fn((fn: (t: unknown) => Promise<unknown>) => fn(tx)),
  };
  return { svc: new AdminService(prisma as never), prisma, userCreate, personLink };
}

const DTO = {
  email: 'trainee2@banan.local',
  password: 'Vietnam123',
  fullName: 'Trainee 2',
  role: ProvisionableRole.TRAINEE,
  personId: 'person1',
};

describe('AdminService.createUser TRAINEE ↔ InternalPerson link', () => {
  it('creates the user AND links the person in ONE transaction', async () => {
    const m = makeService();
    await m.svc.createUser(DTO as never);
    expect(m.userCreate).toHaveBeenCalledTimes(1);
    expect(m.userCreate.mock.calls[0][0].data.role).toBe('TRAINEE');
    // Link guarded on the person still being free.
    expect(m.personLink).toHaveBeenCalledWith({
      where: { id: 'person1', userId: null },
      data: { userId: 'u-new' },
    });
  });

  it('TRAINEE without personId is refused — no orphan trainee logins', async () => {
    const m = makeService();
    await expect(m.svc.createUser({ ...DTO, personId: undefined } as never)).rejects.toMatchObject({
      response: { code: 'PERSON_REQUIRED' },
    });
    expect(m.prisma.$transaction).not.toHaveBeenCalled();
  });

  it('an unknown person is refused before any write', async () => {
    const m = makeService({ person: null });
    await expect(m.svc.createUser(DTO as never)).rejects.toMatchObject({
      response: { code: 'PERSON_NOT_FOUND' },
    });
    expect(m.prisma.$transaction).not.toHaveBeenCalled();
  });

  it('a person already holding an account is refused (pre-check)', async () => {
    const m = makeService({ person: { userId: 'someone-else' } });
    await expect(m.svc.createUser(DTO as never)).rejects.toMatchObject({
      response: { code: 'PERSON_ALREADY_LINKED' },
    });
  });

  it('a CONCURRENT link steals the person → the whole create rolls back', async () => {
    // Pre-check saw userId null, but the guarded updateMany inside the tx
    // matched 0 rows — someone linked the person in between.
    const m = makeService({ linkCount: 0 });
    await expect(m.svc.createUser(DTO as never)).rejects.toMatchObject({
      response: { code: 'PERSON_ALREADY_LINKED' },
    });
  });

  it('non-trainee roles never touch InternalPerson', async () => {
    const m = makeService();
    await m.svc.createUser({
      email: 'c@x.vn',
      password: 'password1',
      fullName: 'C',
      role: ProvisionableRole.CUSTOMER,
    } as never);
    expect(m.personLink).not.toHaveBeenCalled();
    expect(m.prisma.internalPerson.findUnique).not.toHaveBeenCalled();
  });
});

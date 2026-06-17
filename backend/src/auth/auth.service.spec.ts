import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import bcrypt from 'bcrypt';

import { AuthService } from './auth.service';

/** Minimal mocks — no DB. */
function makeService(overrides: {
  userCreate?: jest.Mock;
  userFindFirst?: jest.Mock;
}) {
  const prisma = {
    user: {
      create: overrides.userCreate ?? jest.fn(),
      findFirst: overrides.userFindFirst ?? jest.fn(),
    },
    refreshToken: { create: jest.fn().mockResolvedValue({}) },
  };
  const jwt = { signAsync: jest.fn().mockResolvedValue('access.jwt') };
  const config = { get: jest.fn().mockReturnValue('secret') };
  // register()/login() don't send mail, but the constructor now requires an
  // EmailService — supply an inert mock so the suite compiles + runs.
  const email = {
    sendWelcome: jest.fn().mockResolvedValue(undefined),
    sendRaw: jest.fn().mockResolvedValue(undefined),
    sendPasswordReset: jest.fn().mockResolvedValue(undefined),
  };
  const svc = new AuthService(
    prisma as never,
    jwt as never,
    config as never,
    email as never,
  );
  return { svc, prisma, jwt };
}

describe('AuthService', () => {
  it('register() hashes the password and issues a session', async () => {
    const created = {
      id: 'u1',
      email: 'a@b.com',
      role: 'CUSTOMER',
      passwordHash: 'x',
      storeId: null,
      kitchenId: null,
    };
    const userCreate = jest.fn().mockResolvedValue(created);
    const { svc } = makeService({ userCreate });

    const out = await svc.register({
      email: 'A@B.com',
      password: 'supersecret',
      fullName: 'A',
    } as never);

    expect(userCreate).toHaveBeenCalledTimes(1);
    const data = userCreate.mock.calls[0][0].data;
    expect(data.email).toBe('a@b.com'); // lower-cased
    expect(data.passwordHash).not.toBe('supersecret'); // hashed
    expect(out.accessToken).toBe('access.jwt');
    expect(out.refreshToken).toEqual(expect.any(String));
    expect(out.user).toBe(created);
  });

  it('register() maps a unique-constraint hit to 409 Conflict', async () => {
    const p2002 = new Prisma.PrismaClientKnownRequestError('dup', {
      code: 'P2002',
      clientVersion: 'test',
    });
    const { svc } = makeService({
      userCreate: jest.fn().mockRejectedValue(p2002),
    });
    await expect(
      svc.register({
        email: 'a@b.com',
        password: 'supersecret',
        fullName: 'A',
      } as never),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('login() rejects an unknown account', async () => {
    const { svc } = makeService({
      userFindFirst: jest.fn().mockResolvedValue(null),
    });
    await expect(
      svc.login({ emailOrPhone: 'nope@x.com', password: 'p' } as never),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('login() rejects a wrong password', async () => {
    const hash = await bcrypt.hash('correct-horse', 10);
    const { svc } = makeService({
      userFindFirst: jest.fn().mockResolvedValue({
        id: 'u1',
        email: 'a@b.com',
        passwordHash: hash,
        role: 'CUSTOMER',
        storeId: null,
        kitchenId: null,
        isActive: true,
      }),
    });
    await expect(
      svc.login({ emailOrPhone: 'a@b.com', password: 'wrong' } as never),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('login() succeeds with the right password', async () => {
    const hash = await bcrypt.hash('correct-horse', 10);
    const { svc } = makeService({
      userFindFirst: jest.fn().mockResolvedValue({
        id: 'u1',
        email: 'a@b.com',
        passwordHash: hash,
        role: 'CUSTOMER',
        storeId: null,
        kitchenId: null,
        isActive: true,
      }),
    });
    const out = await svc.login({
      emailOrPhone: 'a@b.com',
      password: 'correct-horse',
    } as never);
    expect(out.accessToken).toBe('access.jwt');
  });
});

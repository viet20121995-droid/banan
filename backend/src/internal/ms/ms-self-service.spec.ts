import { Reflector } from '@nestjs/core';
import { Prisma } from '@prisma/client';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

import { IS_PUBLIC_KEY } from '../../auth/decorators/public.decorator';

import { SelfServiceCreateDto } from './dto';
import { MsPublicController } from './ms-public.controller';
import { MsService } from './ms.service';

const GOOD_CODE = 'banan-secret-code';

function makeService(
  opts: {
    envCode?: string | null;
    store?: boolean;
    template?: boolean;
    createThrowsP2002?: boolean;
    existing?: {
      status?: string;
      firstOpenedAt?: Date | null;
    } | null;
  } = {},
) {
  const assignmentCreate = jest.fn().mockImplementation(() => {
    if (opts.createThrowsP2002) {
      throw new Prisma.PrismaClientKnownRequestError('dup', {
        code: 'P2002',
        clientVersion: 'test',
      });
    }
    return Promise.resolve({ id: 'ms1' });
  });
  const tokenCreate = jest.fn().mockResolvedValue({});
  const tokenRevoke = jest.fn().mockResolvedValue({ count: 1 });
  const tx = {
    msTemplate: {
      findFirst: jest.fn().mockResolvedValue((opts.template ?? true) ? { id: 'tpl1' } : null),
    },
    msAssignment: { create: assignmentCreate, findUnique: jest.fn().mockResolvedValue(null) },
    msAccessToken: { create: tokenCreate },
  };
  const prisma = {
    store: {
      findUnique: jest
        .fn()
        .mockResolvedValue((opts.store ?? true) ? { id: 's1', name: 'Banan LTT' } : null),
    },
    msAssignment: {
      findUnique: jest.fn().mockResolvedValue(
        opts.existing
          ? {
              id: 'ms-existing',
              code: 'MS-2026-EXIST',
              status: opts.existing.status ?? 'ASSIGNED',
              firstOpenedAt: opts.existing.firstOpenedAt ?? null,
              deadline: new Date('2026-09-05T00:00:00Z'),
              store: { name: 'Banan LTT' },
            }
          : null,
      ),
    },
    msAccessToken: { updateMany: tokenRevoke, create: tokenCreate },
    $transaction: jest.fn(async (arg: unknown) => {
      if (typeof arg === 'function') return (arg as (t: unknown) => Promise<unknown>)(tx);
      return Promise.all(arg as Promise<unknown>[]);
    }),
  };
  const config = {
    get: jest.fn((key: string) =>
      key === 'INTERNAL_MS_CREATOR_CODE'
        ? opts.envCode === null
          ? undefined
          : (opts.envCode ?? GOOD_CODE)
        : undefined,
    ),
  };
  const svc = new MsService(prisma as never, config as never, {} as never);
  return { svc, prisma, tx, assignmentCreate, tokenCreate, tokenRevoke };
}

const DTO = {
  requesterName: 'Nguyễn Văn A',
  employeeCode: 'NV012',
  accessCode: GOOD_CODE,
  storeId: 's1',
  ttlDays: 7,
  note: 'ca chiều',
  idempotencyKey: 'key-1234567890abcdef',
};

describe('MsService.selfServiceCreate', () => {
  it('correct code creates exactly one assignment + one token, all server-decided', async () => {
    const m = makeService();
    const res = await m.svc.selfServiceCreate(DTO as never);

    expect(m.assignmentCreate).toHaveBeenCalledTimes(1);
    const data = m.assignmentCreate.mock.calls[0][0].data;
    expect(data.source).toBe('EMPLOYEE_SELF_SERVICE');
    expect(data.status).toBe('ASSIGNED');
    expect(data.templateId).toBe('tpl1'); // server-chosen — never from the client
    expect(data.requesterName).toBe('Nguyễn Văn A');
    expect(data.requesterEmployeeCode).toBe('NV012');
    expect(data.selfServiceKey).toBe(DTO.idempotencyKey);
    expect(data.createdById).toBe('EMPLOYEE_SELF_SERVICE');

    expect(m.tokenCreate).toHaveBeenCalledTimes(1);
    const token = m.tokenCreate.mock.calls[0][0].data;
    // Only the sha256 hash is stored; the raw token lives in the url once.
    expect(token.tokenHash).toMatch(/^[a-f0-9]{64}$/);
    expect(res.url).toContain('/f/');
    expect(res.url).not.toContain(token.tokenHash);
    expect(res.storeName).toBe('Banan LTT');
  });

  it('a wrong access code is rejected and NOTHING is written', async () => {
    const m = makeService();
    await expect(
      m.svc.selfServiceCreate({ ...DTO, accessCode: 'wrong' } as never),
    ).rejects.toMatchObject({ response: { code: 'INTERNAL_MS_CODE_INVALID' } });
    expect(m.prisma.$transaction).not.toHaveBeenCalled();
    expect(m.assignmentCreate).not.toHaveBeenCalled();
  });

  it('an unset INTERNAL_MS_CREATOR_CODE fails closed (503) before any read', async () => {
    const m = makeService({ envCode: null });
    await expect(m.svc.selfServiceCreate(DTO as never)).rejects.toMatchObject({
      response: { code: 'INTERNAL_MS_CREATOR_DISABLED' },
    });
    expect(m.prisma.store.findUnique).not.toHaveBeenCalled();
    expect(m.assignmentCreate).not.toHaveBeenCalled();
  });

  it('an unknown store is rejected without creating anything', async () => {
    const m = makeService({ store: false });
    await expect(m.svc.selfServiceCreate(DTO as never)).rejects.toMatchObject({
      response: { code: 'INTERNAL_MS_STORE_NOT_FOUND' },
    });
    expect(m.assignmentCreate).not.toHaveBeenCalled();
  });

  it('TTL is clamped to 1–7 days server-side even if validation is bypassed', async () => {
    const m = makeService();
    const before = Date.now();
    const res = await m.svc.selfServiceCreate({ ...DTO, ttlDays: 99 } as never);
    const expires = new Date(res.expiresAt).getTime();
    expect(expires - before).toBeLessThanOrEqual(7 * 86_400_000 + 5_000);
    expect(expires - before).toBeGreaterThan(6 * 86_400_000);
  });

  it('two SIMULTANEOUS same-key requests never mint a second mission (P2002)', async () => {
    const m = makeService({ createThrowsP2002: true });
    await expect(m.svc.selfServiceCreate(DTO as never)).rejects.toMatchObject({
      response: { code: 'INTERNAL_MS_DUPLICATE_REQUEST' },
    });
    expect(m.tokenCreate).not.toHaveBeenCalled();
  });

  it('a RETRY after a lost response re-issues a working link for the untouched mission', async () => {
    const m = makeService({ existing: {} }); // ASSIGNED, never opened
    const res = await m.svc.selfServiceCreate(DTO as never);
    // Same mission, fresh token: no second assignment, old links revoked.
    expect(m.assignmentCreate).not.toHaveBeenCalled();
    expect(m.tokenRevoke).toHaveBeenCalledWith({
      where: { assignmentId: 'ms-existing', revokedAt: null },
      data: { revokedAt: expect.any(Date) },
    });
    expect(m.tokenCreate).toHaveBeenCalledTimes(1);
    expect(res.code).toBe('MS-2026-EXIST');
    expect(res.url).toContain('/f/');
    // Retry keeps the ORIGINAL expiry window.
    expect(res.expiresAt).toBe('2026-09-05T00:00:00.000Z');
  });

  it('a retry after the link was OPENED is a hard duplicate — nothing re-issued', async () => {
    const m = makeService({ existing: { firstOpenedAt: new Date() } });
    await expect(m.svc.selfServiceCreate(DTO as never)).rejects.toMatchObject({
      response: { code: 'INTERNAL_MS_DUPLICATE_REQUEST' },
    });
    expect(m.tokenRevoke).not.toHaveBeenCalled();
    expect(m.tokenCreate).not.toHaveBeenCalled();
  });

  it('a retry on a finished/revoked mission is refused too', async () => {
    const m = makeService({ existing: { status: 'REVOKED' } });
    await expect(m.svc.selfServiceCreate(DTO as never)).rejects.toMatchObject({
      response: { code: 'INTERNAL_MS_DUPLICATE_REQUEST' },
    });
    expect(m.tokenCreate).not.toHaveBeenCalled();
  });

  it('a missing active template aborts inside the transaction', async () => {
    const m = makeService({ template: false });
    await expect(m.svc.selfServiceCreate(DTO as never)).rejects.toMatchObject({
      response: { code: 'INTERNAL_MS_NO_TEMPLATE' },
    });
    expect(m.assignmentCreate).not.toHaveBeenCalled();
  });
});

describe('SelfServiceCreateDto (whitelist)', () => {
  // The service mock takes any id; the DTO layer insists on a real UUID.
  const base = { ...DTO, storeId: '3f2c8a44-9d1e-4b7a-8c55-2f9e01d6b7aa' };

  async function violations(payload: Record<string, unknown>) {
    return validate(plainToInstance(SelfServiceCreateDto, payload), {
      whitelist: true,
      forbidNonWhitelisted: true,
    });
  }

  it('accepts the legit payload', async () => {
    expect(await violations(base)).toHaveLength(0);
  });

  it.each(['templateId', 'status', 'recipients', 'approvedRevision', 'reportSnapshot'])(
    'rejects a smuggled %s field outright',
    async (field) => {
      const errs = await violations({ ...base, [field]: 'x' });
      expect(errs.length).toBeGreaterThan(0);
    },
  );

  it('rejects ttlDays outside 1–7', async () => {
    expect((await violations({ ...base, ttlDays: 0 })).length).toBeGreaterThan(0);
    expect((await violations({ ...base, ttlDays: 8 })).length).toBeGreaterThan(0);
  });

  it('rejects whitespace-only requesterName / accessCode (audit fields must have substance)', async () => {
    expect((await violations({ ...base, requesterName: '   ' })).length).toBeGreaterThan(0);
    expect((await violations({ ...base, accessCode: ' \t ' })).length).toBeGreaterThan(0);
  });
});

describe('MsPublicController.createAssignment', () => {
  it('is @Public (access-code gated, not JWT gated)', () => {
    const reflector = new Reflector();
    const isPublic = reflector.get<boolean>(
      IS_PUBLIC_KEY,
      MsPublicController.prototype.createAssignment,
    );
    expect(isPublic).toBe(true);
  });
});

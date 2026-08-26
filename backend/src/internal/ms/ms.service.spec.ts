import { createHash } from 'node:crypto';

import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';

import { ROLES_KEY } from '../../auth/decorators/roles.decorator';

import { MsController } from './ms.controller';
import { MsService } from './ms.service';

function submissionFixture() {
  return {
    id: 'sub1',
    assignmentId: 'ms1',
    submittedAt: new Date(),
    enteredAt: null,
    greetedAt: null,
    orderStartAt: null,
    paidAt: null,
    receivedAt: null,
    productsBought: null,
    amountPaidVnd: null,
    staffName: null,
    overallComment: null,
    criticalFail: false,
    totalScore: null,
    answers: [],
    evidence: [],
  };
}

function assignmentFixture(status = 'OPENED', withSubmission = false) {
  return {
    id: 'ms1',
    code: 'MS-2026-ABCDE',
    templateId: 'tpl1',
    storeId: 's1',
    status,
    revisionNote: null,
    firstOpenedAt: new Date(),
    approvedRevision: 0,
    approvedAt: null,
    windowStart: null,
    windowEnd: null,
    scenario: null,
    productsToBuy: null,
    budgetVnd: null,
    brief: null,
    deadline: null,
    internalNotes: 'BÍ MẬT NỘI BỘ',
    createdAt: new Date(),
    store: { id: 's1', name: 'Banan LTT', slug: 'x' },
    template: { sections: [] },
    submission: withSubmission ? submissionFixture() : null,
  };
}

function makeService(opts: {
  token?: {
    revokedAt?: Date | null;
    expiresAt?: Date;
    assignment?: ReturnType<typeof assignmentFixture>;
  } | null;
  lockedStatus?: string;
  approveClaim?: number;
}) {
  const assignment = opts.token?.assignment ?? assignmentFixture();
  const tokenRow =
    opts.token === null
      ? null
      : {
          id: 't1',
          assignmentId: assignment.id,
          tokenHash: 'stored-hash',
          revokedAt: opts.token?.revokedAt ?? null,
          expiresAt: opts.token?.expiresAt ?? new Date(Date.now() + 86_400_000),
          assignment,
        };
  const tokenCreate = jest.fn().mockResolvedValue({});
  const tokenUpdateMany = jest.fn().mockResolvedValue({ count: 0 });
  const assignmentUpdateMany = jest.fn().mockResolvedValue({ count: opts.approveClaim ?? 1 });
  const deliveryCreate = jest.fn().mockResolvedValue({});
  const submissionUpdate = jest.fn().mockResolvedValue({});
  const approvable = assignmentFixture('SUBMITTED', true);
  const tx = {
    $queryRaw: jest
      .fn()
      .mockResolvedValue([{ id: assignment.id, status: opts.lockedStatus ?? 'SUBMITTED' }]),
    msAssignment: {
      updateMany: assignmentUpdateMany,
      findUniqueOrThrow: jest
        .fn()
        .mockResolvedValueOnce(approvable)
        .mockResolvedValue({ approvedRevision: 1 }),
      update: jest.fn().mockResolvedValue({}),
    },
    msSubmission: { update: submissionUpdate, upsert: jest.fn().mockResolvedValue({ id: 'sub1' }) },
    msAnswer: { upsert: jest.fn().mockResolvedValue({ id: 'a1' }) },
    msEvidence: { create: jest.fn(), findUnique: jest.fn(), delete: jest.fn() },
    msReportDelivery: { create: deliveryCreate },
  };
  const prisma = {
    msAccessToken: {
      findUnique: jest.fn().mockResolvedValue(tokenRow),
      updateMany: tokenUpdateMany,
      create: tokenCreate,
    },
    msAssignment: {
      findUnique: jest.fn().mockResolvedValue({ ...assignment, tokens: [] }),
      findUniqueOrThrow: jest.fn().mockResolvedValue(assignment),
      updateMany: assignmentUpdateMany,
      update: jest.fn().mockResolvedValue(assignment),
    },
    store: { findUnique: jest.fn().mockResolvedValue({ id: 's1' }) },
    $transaction: jest.fn(async (arg: unknown) => {
      if (typeof arg === 'function') return (arg as (t: unknown) => Promise<unknown>)(tx);
      return Promise.all(arg as Promise<unknown>[]);
    }),
  };
  const config = { get: jest.fn().mockReturnValue(undefined) };
  const svc = new MsService(prisma as never, config as never);
  return {
    svc,
    prisma,
    tx,
    tokenCreate,
    tokenUpdateMany,
    deliveryCreate,
    submissionUpdate,
    assignment,
  };
}

describe('MsService tokens', () => {
  it('issueToken stores ONLY the sha256 hash — never the raw token', async () => {
    const m = makeService({});
    const res = await m.svc.issueToken('ms1', {}, 'admin');
    expect(res.token).toHaveLength(43);
    const stored = m.tokenCreate.mock.calls[0][0].data.tokenHash;
    expect(stored).not.toBe(res.token);
    expect(stored).toBe(createHash('sha256').update(res.token, 'utf8').digest('hex'));
    expect(res.url).toContain(`/f/${res.token}`);
    // Old tokens revoked on regenerate.
    expect(m.tokenUpdateMany).toHaveBeenCalled();
  });

  it('an expired token is refused and lazily EXPIREs the assignment', async () => {
    const m = makeService({ token: { expiresAt: new Date(Date.now() - 1000) } });
    await expect(m.svc.publicView('raw')).rejects.toMatchObject({
      response: { code: 'INTERNAL_MS_LINK_EXPIRED' },
    });
    expect(m.prisma.msAssignment.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ data: { status: 'EXPIRED' } }),
    );
  });

  it('a revoked token is refused', async () => {
    const m = makeService({ token: { revokedAt: new Date() } });
    await expect(m.svc.publicView('raw')).rejects.toMatchObject({
      response: { code: 'INTERNAL_MS_LINK_REVOKED' },
    });
  });

  it('an unknown token 404s — it can never reach another assignment', async () => {
    const m = makeService({ token: null });
    await expect(m.svc.publicView('raw')).rejects.toMatchObject({
      response: { code: 'INTERNAL_MS_LINK_INVALID' },
    });
  });

  it('the public payload never leaks internal notes', async () => {
    const m = makeService({});
    const view = await m.svc.publicView('raw');
    expect(JSON.stringify(view)).not.toContain('BÍ MẬT');
    expect((view as Record<string, unknown>).internalNotes).toBeUndefined();
  });
});

describe('MsService.publicSubmit', () => {
  it('double submit is an idempotent no-op success', async () => {
    const m = makeService({ token: { assignment: assignmentFixture('SUBMITTED') } });
    const view = await m.svc.publicSubmit('raw');
    expect((view as { status: string }).status).toBe('SUBMITTED');
    // No state writes happened.
    expect(m.prisma.$transaction).not.toHaveBeenCalled();
  });

  it('a save racing an approve is rejected by the in-tx status re-check', async () => {
    // Token snapshot says OPENED, but by the time the lock is taken the
    // assignment was approved — the locked status wins.
    const m = makeService({
      token: { assignment: assignmentFixture('OPENED') },
      lockedStatus: 'APPROVED',
    });
    await expect(m.svc.publicSave({ token: 'raw', answers: [] })).rejects.toMatchObject({
      response: { code: 'INTERNAL_MS_NOT_EDITABLE' },
    });
    expect(m.tx.msSubmission.upsert).not.toHaveBeenCalled();
  });
});

describe('MsService.approve (all under the row lock)', () => {
  it('a non-SUBMITTED locked status is rejected before any write', async () => {
    const m = makeService({ lockedStatus: 'OPENED' });
    await expect(m.svc.approve('ms1', 'admin')).rejects.toMatchObject({
      response: { code: 'INTERNAL_MS_NOT_SUBMITTED' },
    });
    expect(m.deliveryCreate).not.toHaveBeenCalled();
  });

  it('a lost claim (count 0) throws and creates NO delivery', async () => {
    const m = makeService({ approveClaim: 0 });
    await expect(m.svc.approve('ms1', 'admin')).rejects.toMatchObject({
      response: { code: 'INTERNAL_MS_NOT_SUBMITTED' },
    });
    expect(m.deliveryCreate).not.toHaveBeenCalled();
  });

  it('approval snapshots the result IN the transaction and creates ONE delivery with all 3 MS recipients', async () => {
    const m = makeService({});
    const res = await m.svc.approve('ms1', 'admin');
    expect(res).toEqual({ assignmentId: 'ms1', revision: 1 });
    expect(m.submissionUpdate).toHaveBeenCalled();
    expect(m.prisma.$transaction).toHaveBeenCalledTimes(1);
    const data = m.deliveryCreate.mock.calls[0][0].data;
    expect(data.recipients).toEqual([
      'operationmanager@banancakes.com',
      'ntyen104@gmail.com',
      'ducnguyen@vestav.com',
    ]);
    // Immutable snapshot frozen in the same tx, revision stamped POST-increment.
    expect(data.reportSnapshot).toMatchObject({
      revision: 1,
      pdf: expect.objectContaining({ revision: 1 }),
    });
  });
});

describe('MsService.adminDetail token hygiene', () => {
  it('token rows expose metadata only — no hash, no raw token field', async () => {
    const m = makeService({});
    m.prisma.msAssignment.findUnique = jest.fn().mockResolvedValue({
      ...m.assignment,
      tokens: [
        {
          id: 't1',
          tokenHash: 'stored-hash',
          createdAt: new Date(),
          expiresAt: new Date(),
          revokedAt: null,
        },
      ],
    });
    const detail = await m.svc.adminDetail('ms1');
    const token = (detail as { tokens: Record<string, unknown>[] }).tokens[0];
    expect(Object.keys(token).sort()).toEqual(['createdAt', 'expiresAt', 'id', 'revokedAt']);
    expect(JSON.stringify(detail)).not.toContain('stored-hash');
  });
});

describe('MsController authorization metadata', () => {
  it('the admin controller is gated to ADMIN only', () => {
    const roles = new Reflector().get<Role[]>(ROLES_KEY, MsController);
    expect(roles).toEqual([Role.ADMIN]);
  });
});

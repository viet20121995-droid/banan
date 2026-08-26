import { BadRequestException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';

import { ROLES_KEY } from '../../auth/decorators/roles.decorator';

import { QcController } from './qc.controller';
import { QcService } from './qc.service';

/** Inspection fixture: 1 normal section (2 items) + risk section (1 item). */
function fixture(opts: {
  answers?: Record<
    string,
    { value: string; failDetail?: string; naReason?: string; evidence?: number }
  >;
  risks?: Record<string, { occurred: boolean | null; detail?: string; evidence?: number }>;
  status?: string;
}) {
  const answers = Object.entries(opts.answers ?? {}).map(([itemId, a]) => ({
    itemId,
    value: a.value,
    failDetail: a.failDetail ?? null,
    naReason: a.naReason ?? null,
    evidence: Array.from({ length: a.evidence ?? 0 }, (_, i) => ({
      id: `e${i}`,
      url: 'a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg',
    })),
  }));
  const riskAnswers = Object.entries(opts.risks ?? {}).map(([itemId, r]) => ({
    itemId,
    occurred: r.occurred,
    detail: r.detail ?? null,
    evidence: Array.from({ length: r.evidence ?? 0 }, (_, i) => ({
      id: `re${i}`,
      url: 'b1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg',
    })),
  }));
  return {
    id: 'insp1',
    templateId: 'tpl1',
    status: opts.status ?? 'IN_PROGRESS',
    revision: 0,
    inspectionDate: new Date('2026-08-20T00:00:00Z'),
    startedAt: null,
    endedAt: null,
    inspectorName: 'admin',
    staffOnShift: null,
    generalNotes: null,
    completedAt: null,
    store: { id: 's1', name: 'Banan LTT', slug: 'banan-le-thanh-ton' },
    template: {
      sections: [
        {
          id: 'sec1',
          title: 'Section 1',
          isRisk: false,
          items: [
            { id: 'i1', text: 'Item 1', sortOrder: 0, sourceRef: '1' },
            { id: 'i2', text: 'Item 2', sortOrder: 1, sourceRef: '2' },
          ],
        },
        {
          id: 'risk',
          title: 'RISK',
          isRisk: true,
          items: [{ id: 'r1', text: 'Risk 1', sortOrder: 0, sourceRef: '1' }],
        },
      ],
    },
    answers,
    riskAnswers,
  };
}

/** Mocks the full transactional shape: FOR UPDATE lock, tx reads, claim. */
function makeService(insp: ReturnType<typeof fixture>, opts: { claimCount?: number } = {}) {
  const updateMany = jest.fn().mockResolvedValue({ count: opts.claimCount ?? 1 });
  const deliveryCreate = jest.fn().mockResolvedValue({});
  const lock = jest
    .fn()
    .mockResolvedValue([{ id: insp.id, status: insp.status, templateId: insp.templateId }]);
  const tx = {
    $queryRaw: lock,
    qcInspection: {
      updateMany,
      // First tx read = full inspection for validation/scoring; the second
      // read (post-claim) only needs the bumped revision.
      findUniqueOrThrow: jest.fn().mockResolvedValueOnce(insp).mockResolvedValue({ revision: 1 }),
      update: jest.fn().mockResolvedValue({}),
    },
    qcItem: { findUnique: jest.fn().mockResolvedValue(null) },
    qcInspectionAnswer: { upsert: jest.fn(), findUnique: jest.fn() },
    qcRiskAnswer: { upsert: jest.fn(), findUnique: jest.fn() },
    qcEvidence: { create: jest.fn(), findUnique: jest.fn(), delete: jest.fn() },
    qcReportDelivery: { create: deliveryCreate },
  };
  const prisma = {
    qcInspection: { findUnique: jest.fn().mockResolvedValue(insp) },
    $transaction: jest.fn((fn: (t: unknown) => Promise<unknown>) => fn(tx)),
  };
  const config = { get: jest.fn().mockReturnValue(undefined) };
  const svc = new QcService(prisma as never, config as never);
  return { svc, prisma, tx, lock, updateMany, deliveryCreate };
}

const validAnswers = {
  answers: {
    i1: { value: 'PASS' },
    i2: { value: 'FAIL', failDetail: 'hỏng', evidence: 1 },
  },
  risks: { r1: { occurred: false } },
};

describe('QcService.complete validation (all under the row lock)', () => {
  it('locks the inspection FOR UPDATE before reading answers', async () => {
    const m = makeService(fixture(validAnswers));
    await m.svc.complete('insp1', 'admin');
    expect(m.lock).toHaveBeenCalled();
    // Lock happens inside the same transaction as the claim.
    expect(m.prisma.$transaction).toHaveBeenCalledTimes(1);
  });

  it('rejects while any item is unanswered', async () => {
    const m = makeService(
      fixture({ answers: { i1: { value: 'PASS' } }, risks: { r1: { occurred: false } } }),
    );
    await expect(m.svc.complete('insp1', 'admin')).rejects.toMatchObject({
      response: { code: 'INTERNAL_QC_INCOMPLETE' },
    });
    expect(m.updateMany).not.toHaveBeenCalled();
    expect(m.deliveryCreate).not.toHaveBeenCalled();
  });

  it('rejects FAIL without detail and FAIL without evidence', async () => {
    const noDetail = makeService(
      fixture({
        answers: { i1: { value: 'PASS' }, i2: { value: 'FAIL', evidence: 1 } },
        risks: { r1: { occurred: false } },
      }),
    );
    await expect(noDetail.svc.complete('insp1', 'admin')).rejects.toBeInstanceOf(
      BadRequestException,
    );

    const noEvidence = makeService(
      fixture({
        answers: { i1: { value: 'PASS' }, i2: { value: 'FAIL', failDetail: 'x' } },
        risks: { r1: { occurred: false } },
      }),
    );
    await expect(noEvidence.svc.complete('insp1', 'admin')).rejects.toMatchObject({
      response: { code: 'INTERNAL_QC_INCOMPLETE' },
    });
  });

  it('rejects NOT_AVAILABLE without a reason', async () => {
    const m = makeService(
      fixture({
        answers: { i1: { value: 'PASS' }, i2: { value: 'NOT_AVAILABLE' } },
        risks: { r1: { occurred: false } },
      }),
    );
    await expect(m.svc.complete('insp1', 'admin')).rejects.toMatchObject({
      response: { code: 'INTERNAL_QC_INCOMPLETE' },
    });
  });

  it('rejects an occurred risk missing detail or photo', async () => {
    const m = makeService(
      fixture({
        answers: { i1: { value: 'PASS' }, i2: { value: 'PASS' } },
        risks: { r1: { occurred: true, detail: 'x' } }, // no evidence
      }),
    );
    await expect(m.svc.complete('insp1', 'admin')).rejects.toMatchObject({
      response: { code: 'INTERNAL_QC_INCOMPLETE' },
    });
  });

  it('a COMPLETED inspection is rejected at the lock, before any write', async () => {
    const m = makeService(fixture({ ...validAnswers, status: 'COMPLETED' }));
    await expect(m.svc.complete('insp1', 'admin')).rejects.toMatchObject({
      response: { code: 'INTERNAL_QC_LOCKED' },
    });
    expect(m.updateMany).not.toHaveBeenCalled();
  });
});

describe('QcService.complete transaction', () => {
  it('creates exactly one delivery row for the new revision with the QC recipients', async () => {
    const m = makeService(fixture(validAnswers));
    const res = await m.svc.complete('insp1', 'admin');
    expect(res).toEqual({ inspectionId: 'insp1', revision: 1 });
    expect(m.deliveryCreate).toHaveBeenCalledTimes(1);
    const data = m.deliveryCreate.mock.calls[0][0].data;
    expect(data.revision).toBe(1);
    expect(data.recipients).toEqual(['operationmanager@banancakes.com', 'ntyen104@gmail.com']);
    expect(data.recipients).not.toContain('ducnguyen@vestav.com');
    // Immutable snapshot frozen in the same tx, revision stamped POST-increment.
    expect(data.reportSnapshot).toMatchObject({
      revision: 1,
      pdf: expect.objectContaining({ revision: 1 }),
      result: expect.objectContaining({ outcome: 'FAIL' }), // 1/2 PASS = 50%
    });
  });

  it('a lost complete race (claim count 0) throws and creates NO delivery', async () => {
    const m = makeService(fixture(validAnswers), { claimCount: 0 });
    await expect(m.svc.complete('insp1', 'admin')).rejects.toMatchObject({
      response: { code: 'INTERNAL_QC_ALREADY_COMPLETED' },
    });
    expect(m.deliveryCreate).not.toHaveBeenCalled();
  });
});

describe('QcService.reopen', () => {
  it('only a COMPLETED inspection reopens (guarded updateMany)', async () => {
    const updateMany = jest.fn().mockResolvedValue({ count: 0 });
    const prisma = { qcInspection: { updateMany } };
    const svc = new QcService(prisma as never, { get: () => undefined } as never);
    await expect(svc.reopen('insp1', 'admin')).rejects.toMatchObject({
      response: { code: 'INTERNAL_QC_NOT_COMPLETED' },
    });
  });
});

describe('QcService.upsertAnswer (locked)', () => {
  it('rejects an item from another template — under the lock', async () => {
    const m = makeService(fixture(validAnswers));
    m.tx.qcItem.findUnique = jest
      .fn()
      .mockResolvedValue({ id: 'other', section: { templateId: 'OTHER_TPL', isRisk: false } });
    await expect(
      m.svc.upsertAnswer('insp1', 'other', { value: 'PASS' }, 'admin'),
    ).rejects.toMatchObject({ response: { code: 'INTERNAL_QC_ITEM_MISMATCH' } });
    expect(m.tx.qcInspectionAnswer.upsert).not.toHaveBeenCalled();
  });

  it('a write racing a finished complete is rejected by the in-tx status check', async () => {
    const m = makeService(fixture({ ...validAnswers, status: 'COMPLETED' }));
    await expect(
      m.svc.upsertAnswer('insp1', 'i1', { value: 'PASS' }, 'admin'),
    ).rejects.toMatchObject({ response: { code: 'INTERNAL_QC_LOCKED' } });
    expect(m.tx.qcInspectionAnswer.upsert).not.toHaveBeenCalled();
  });
});

describe('QcController authorization metadata', () => {
  it('the whole controller is gated to ADMIN only', () => {
    const roles = new Reflector().get<Role[]>(ROLES_KEY, QcController);
    expect(roles).toEqual([Role.ADMIN]);
  });
});

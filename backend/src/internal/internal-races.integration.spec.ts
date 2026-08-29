/**
 * REAL-PostgreSQL integration tests for the race conditions the mocked specs
 * cannot exercise: concurrent outbox dispatch, concurrent complete/approve,
 * answer-writes racing the scoring transaction, and the immutability of the
 * per-revision report snapshot.
 *
 * Opt-in + fenced — this suite WRITES fixtures, so it refuses to touch a
 * normal database:
 *   1. RUN_DB_INTEGRATION_TESTS=1 must be set, otherwise the whole file is
 *      an explicit jest skip (never a silent pass).
 *   2. DATABASE_URL must point at a database whose NAME ends in `_test`,
 *      with migrations applied. Anything else aborts before writing.
 *
 * PowerShell:
 *   $env:RUN_DB_INTEGRATION_TESTS='1'
 *   $env:DATABASE_URL='postgresql://banan:banan@localhost:5432/banan_test?schema=public'
 *   pnpm jest internal-races
 *
 * All fixtures use the IT-RACE- / IT-MS-RACE- / it-race- prefixes and are
 * deleted in afterAll (FK-safe order; template/store cascades cover the rest).
 */
import { ConfigService } from '@nestjs/config';

import { PrismaService } from '../prisma/prisma.service';

import { removePrivateFile } from './files/internal-files.util';
import { InternalReportDeliveryService } from './internal-report-delivery.service';
import { MsService } from './ms/ms.service';
import { InternalPdfService } from './pdf/internal-pdf.service';
import { QcService } from './qc/qc.service';
import { scoreQc } from './qc/qc-scoring';
import { TrainingService } from './training/training.service';

jest.setTimeout(60_000);

const ENABLED = process.env.RUN_DB_INTEGRATION_TESTS === '1';
const describeIf = ENABLED ? describe : describe.skip;

const config = { get: () => undefined } as unknown as ConfigService;
// Real renderer: complete/approve also render + store the approval-time PDF
// into uploads-private (cleaned up in afterAll).
const pdfSvc = new InternalPdfService();
const EVIDENCE_NAME = 'a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg';

describeIf('internal races (real Postgres)', () => {
  let prisma: PrismaService;
  let storeId: string;

  beforeAll(async () => {
    prisma = new PrismaService();
    // Unreachable DB = loud failure. The user opted in; never fake a pass.
    await prisma.$queryRaw`SELECT 1`;
    const [{ current_database: dbName }] = await prisma.$queryRaw<
      { current_database: string }[]
    >`SELECT current_database()`;
    if (!dbName.endsWith('_test')) {
      throw new Error(
        `Refusing to run against "${dbName}" — these tests write fixtures. ` +
          'Point DATABASE_URL at a dedicated *_test database.',
      );
    }
    const store = await prisma.store.create({
      data: {
        name: 'IT-RACE store',
        slug: `it-race-${Date.now()}`,
        address: 'integration-test',
        phone: '0',
        openingHours: {},
      },
    });
    storeId = store.id;
  });

  afterAll(async () => {
    if (!prisma) return;
    try {
      // Report PDFs stored on disk by complete/approve — unlink before the
      // delivery rows (our only pointer to the names) cascade away.
      const [qcPdfs, msPdfs] = await Promise.all([
        prisma.qcReportDelivery.findMany({
          where: { inspection: { template: { name: { startsWith: 'IT-RACE-' } } } },
          select: { pdfFile: true },
        }),
        prisma.msReportDelivery.findMany({
          where: { assignment: { template: { name: { startsWith: 'IT-MS-RACE-' } } } },
          select: { pdfFile: true },
        }),
      ]);
      for (const { pdfFile } of [...qcPdfs, ...msPdfs]) {
        if (pdfFile) removePrivateFile(pdfFile);
      }
      // Inspections/assignments first (their template FKs don't cascade);
      // deleting them cascades answers, evidence, tokens, and deliveries.
      await prisma.qcInspection.deleteMany({
        where: { template: { name: { startsWith: 'IT-RACE-' } } },
      });
      await prisma.qcTemplate.deleteMany({ where: { name: { startsWith: 'IT-RACE-' } } });
      await prisma.msAssignment.deleteMany({
        where: { template: { name: { startsWith: 'IT-MS-RACE-' } } },
      });
      await prisma.msTemplate.deleteMany({ where: { name: { startsWith: 'IT-MS-RACE-' } } });
      // Training race fixtures (assignment cascades its progress rows).
      await prisma.trainingAssignment.deleteMany({
        where: { person: { userId: { startsWith: 'it-race-user-' } } },
      });
      await prisma.trainingPathItem.deleteMany({
        where: { path: { name: { startsWith: 'IT-RACE-path-' } } },
      });
      await prisma.trainingPath.deleteMany({ where: { name: { startsWith: 'IT-RACE-path-' } } });
      await prisma.trainingMaterial.deleteMany({
        where: { title: { startsWith: 'IT-RACE-mat-' } },
      });
      await prisma.internalPerson.deleteMany({
        where: { userId: { startsWith: 'it-race-user-' } },
      });
      await prisma.store.deleteMany({ where: { slug: { startsWith: 'it-race-' } } });
    } finally {
      await prisma.$disconnect();
    }
  });

  /** Tiny 1-item template + IN_PROGRESS inspection with a PASS answer. */
  async function seedRaceFixture() {
    const template = await prisma.qcTemplate.create({
      data: {
        name: `IT-RACE-${Date.now()}-${Math.floor(Math.random() * 1e6)}`,
        version: 1,
        isActive: false, // never the app's active template
        sections: {
          create: [
            {
              title: 'S1',
              sortOrder: 0,
              isRisk: false,
              items: { create: [{ text: 'Item 1', sortOrder: 0 }] },
            },
          ],
        },
      },
      include: { sections: { include: { items: true } } },
    });
    const item = template.sections[0].items[0];
    const inspection = await prisma.qcInspection.create({
      data: {
        templateId: template.id,
        storeId,
        inspectionDate: new Date(),
        inspectorName: 'race-test',
        createdById: 'race-test',
        status: 'IN_PROGRESS',
        answers: { create: [{ itemId: item.id, value: 'PASS' }] },
      },
    });
    return { template, item, inspection };
  }

  function deliveryHarness() {
    const email = { sendInternalReport: jest.fn().mockResolvedValue(true) };
    // readStoredPdf → null forces the render-from-snapshot path, which is
    // what these tests assert on (mock render calls).
    const pdf = {
      renderQcReport: jest.fn().mockResolvedValue(Buffer.from('p')),
      renderMsReport: jest.fn().mockResolvedValue(Buffer.from('p')),
      readStoredPdf: jest.fn().mockReturnValue(null),
    };
    const mk = () =>
      new InternalReportDeliveryService(prisma, email as never, pdf as never, config);
    return { email, pdf, mk };
  }

  describe('outbox: two dispatchers, one delivery row', () => {
    it('exactly ONE email is sent when two workers race the same delivery', async () => {
      const { inspection } = await seedRaceFixture();
      const svc = new QcService(prisma, config, pdfSvc);
      await svc.complete(inspection.id, 'race-test'); // creates the r1 delivery + snapshot

      const { email, mk } = deliveryHarness();
      const [a, b] = [mk(), mk()];
      await Promise.all([a.dispatchQc(inspection.id, 1), b.dispatchQc(inspection.id, 1)]);

      expect(email.sendInternalReport).toHaveBeenCalledTimes(1);
      const row = await prisma.qcReportDelivery.findUniqueOrThrow({
        where: { inspectionId_revision: { inspectionId: inspection.id, revision: 1 } },
      });
      expect(row.status).toBe('SENT');
      expect(row.attempts).toBe(1);
      // complete() also rendered + stored the approval-time PDF (real
      // renderer, real disk write — cleaned up in afterAll).
      expect(row.pdfFile).toMatch(/^[a-f0-9]{32}\.pdf$/);
      expect(pdfSvc.readStoredPdf(row.pdfFile)?.subarray(0, 4).toString()).toBe('%PDF');
    });
  });

  describe('report snapshot immutability', () => {
    it('a retried r1 delivery carries r1 data even after r2 exists', async () => {
      const { inspection, item } = await seedRaceFixture();
      const svc = new QcService(prisma, config, pdfSvc);
      await svc.complete(inspection.id, 'it'); // r1: PASS 100% — delivery stays PENDING

      // Admin reopens, flips the answer to FAIL, completes r2.
      await svc.reopen(inspection.id, 'it');
      await svc.upsertAnswer(inspection.id, item.id, { value: 'FAIL', failDetail: 'r2' }, 'it');
      const answer = await prisma.qcInspectionAnswer.findFirstOrThrow({
        where: { inspectionId: inspection.id },
      });
      await prisma.qcEvidence.create({
        data: { answerId: answer.id, url: EVIDENCE_NAME, mimeType: 'image/jpeg', sizeBytes: 1 },
      });
      await svc.complete(inspection.id, 'it'); // r2: FAIL

      // NOW the r1 delivery is dispatched (as the retry cron would).
      const { email, pdf, mk } = deliveryHarness();
      await mk().dispatchQc(inspection.id, 1);

      expect(email.sendInternalReport).toHaveBeenCalledTimes(1);
      const call = email.sendInternalReport.mock.calls[0][0] as {
        subject: string;
        attachment: { filename: string };
      };
      expect(call.subject).toContain('[QC] ĐẠT'); // r1 outcome, not r2's KHÔNG ĐẠT
      expect(call.attachment.filename).toContain('-r1.pdf');
      const rendered = pdf.renderQcReport.mock.calls[0][0] as {
        revision: number;
        outcome: string;
      };
      expect(rendered.revision).toBe(1);
      expect(rendered.outcome).toBe('PASS');
    });
  });

  describe('QC: concurrent completes and racing answer writes', () => {
    it('two parallel completes produce ONE revision and ONE delivery', async () => {
      const { inspection } = await seedRaceFixture();
      const svc = new QcService(prisma, config, pdfSvc);

      const results = await Promise.allSettled([
        svc.complete(inspection.id, 'race-a'),
        svc.complete(inspection.id, 'race-b'),
      ]);
      const ok = results.filter((r) => r.status === 'fulfilled');
      expect(ok).toHaveLength(1);

      const fresh = await prisma.qcInspection.findUniqueOrThrow({ where: { id: inspection.id } });
      expect(fresh.revision).toBe(1);
      const deliveries = await prisma.qcReportDelivery.count({
        where: { inspectionId: inspection.id },
      });
      expect(deliveries).toBe(1);
    });

    it('an answer write racing complete never yields a stale stored outcome', async () => {
      const { inspection, item } = await seedRaceFixture();
      const svc = new QcService(prisma, config, pdfSvc);

      // Make FAIL a valid final answer so both interleavings are legal.
      await prisma.qcInspectionAnswer.updateMany({
        where: { inspectionId: inspection.id },
        data: { value: 'FAIL', failDetail: 'race' },
      });
      const answer = await prisma.qcInspectionAnswer.findFirstOrThrow({
        where: { inspectionId: inspection.id },
      });
      await prisma.qcEvidence.create({
        data: { answerId: answer.id, url: EVIDENCE_NAME, mimeType: 'image/jpeg', sizeBytes: 1 },
      });

      for (let round = 0; round < 5; round++) {
        // Flip the answer to PASS while complete() is scoring FAIL (or vice
        // versa) — the lock forces one of two legal serialisations.
        const [completed] = await Promise.allSettled([
          svc.complete(inspection.id, 'race-complete'),
          svc.upsertAnswer(inspection.id, item.id, { value: 'PASS' }, 'race-writer'),
        ]);
        expect(completed.status).toBe('fulfilled');

        const fresh = await prisma.qcInspection.findUniqueOrThrow({
          where: { id: inspection.id },
          include: {
            answers: true,
            template: { include: { sections: { include: { items: true } } } },
          },
        });
        // Invariant: the STORED outcome always equals a recompute from the
        // answers that are actually in the DB right now.
        const recomputed = scoreQc(
          fresh.template.sections.map((s) => ({
            sectionId: s.id,
            title: s.title,
            isRisk: s.isRisk,
            values: s.items.map(
              (it) => fresh.answers.find((a) => a.itemId === it.id)?.value ?? null,
            ),
          })),
          false,
        );
        expect(fresh.outcome).toBe(recomputed.outcome);
        expect(fresh.overallPercent).toBe(recomputed.overallPercent);

        // Reset for the next round.
        await prisma.qcInspection.update({
          where: { id: inspection.id },
          data: { status: 'IN_PROGRESS' },
        });
        await prisma.qcInspectionAnswer.updateMany({
          where: { inspectionId: inspection.id },
          data: { value: 'FAIL', failDetail: 'race' },
        });
      }
    });
  });

  describe('MS: approve races', () => {
    async function seedMsFixture() {
      const template = await prisma.msTemplate.create({
        data: {
          name: `IT-MS-RACE-${Date.now()}-${Math.floor(Math.random() * 1e6)}`,
          version: 1,
          isActive: false,
          sections: {
            create: [
              {
                code: 'A',
                title: 'S',
                kind: 'SCORED',
                weight: 100,
                sortOrder: 0,
                questions: { create: [{ text: 'Q1', sortOrder: 0 }] },
              },
            ],
          },
        },
        include: { sections: { include: { questions: true } } },
      });
      const q = template.sections[0].questions[0];
      const assignment = await prisma.msAssignment.create({
        data: {
          code: `MS-IT-${Date.now().toString(36).toUpperCase().slice(-8)}`,
          templateId: template.id,
          storeId,
          status: 'SUBMITTED',
          createdById: 'race-test',
          submission: {
            create: {
              submittedAt: new Date(),
              answers: { create: [{ questionId: q.id, value: 'YES' }] },
            },
          },
        },
      });
      return { assignment, q };
    }

    it('two parallel approvals → one revision, one delivery, snapshot matches answers', async () => {
      const { assignment } = await seedMsFixture();
      const svc = new MsService(prisma, config, pdfSvc);

      const results = await Promise.allSettled([
        svc.approve(assignment.id, 'race-a'),
        svc.approve(assignment.id, 'race-b'),
      ]);
      expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);

      const fresh = await prisma.msAssignment.findUniqueOrThrow({
        where: { id: assignment.id },
        include: { submission: true },
      });
      expect(fresh.approvedRevision).toBe(1);
      expect(fresh.submission?.totalScore).toBe(100); // one YES / weight 100
      const deliveries = await prisma.msReportDelivery.count({
        where: { assignmentId: assignment.id },
      });
      expect(deliveries).toBe(1);
    });

    it('a shopper save racing approve is rejected — the approved snapshot stays consistent', async () => {
      const { assignment, q } = await seedMsFixture();
      const svc = new MsService(prisma, config, pdfSvc);
      // Token path requires a live token; drive publicSave's tx body directly
      // via a second approve-vs-save interleave: SUBMITTED is not editable, so
      // any save (before or after the lock) must reject and can never mutate
      // the answers the approval scored.
      const token = await svc.issueToken(assignment.id, {}, 'race-admin');
      // issueToken flips DRAFT→ASSIGNED only; force back to SUBMITTED.
      await prisma.msAssignment.update({
        where: { id: assignment.id },
        data: { status: 'SUBMITTED' },
      });

      const [approved, saved] = await Promise.allSettled([
        svc.approve(assignment.id, 'race-a'),
        svc.publicSave({
          token: token.token,
          answers: [{ questionId: q.id, value: 'NO' }],
        }),
      ]);
      expect(approved.status).toBe('fulfilled');
      expect(saved.status).toBe('rejected');

      const fresh = await prisma.msAssignment.findUniqueOrThrow({
        where: { id: assignment.id },
        include: { submission: { include: { answers: true } } },
      });
      // The scored snapshot matches the answers in the DB (still YES).
      expect(fresh.submission?.answers[0]?.value).toBe('YES');
      expect(fresh.submission?.totalScore).toBe(100);
    });
  });

  describe('Training: trainee mark racing admin confirmation', () => {
    it("an admin training confirmation is never wiped by the trainee's racing mark", async () => {
      const training = new TrainingService(prisma);
      const userId = `it-race-user-${Date.now()}`;
      const person = await prisma.internalPerson.create({
        data: { fullName: 'IT-RACE trainee', storeId, position: 'IT', userId },
      });
      const material = await prisma.trainingMaterial.create({
        data: {
          title: `IT-RACE-mat-${Date.now()}`,
          category: 'QUY_DINH',
          kind: 'LINK',
          url: 'https://banancakes.vn/it-race',
          isActive: false, // never surfaces in the published library
        },
      });
      const path = await prisma.trainingPath.create({
        data: {
          name: `IT-RACE-path-${Date.now()}`,
          items: { create: [{ materialId: material.id, sortOrder: 0 }] },
        },
        include: { items: true },
      });

      for (let round = 0; round < 5; round++) {
        const assignment = await prisma.trainingAssignment.create({
          data: {
            personId: person.id,
            pathId: path.id,
            startDate: new Date(),
            progress: { create: [{ pathItemId: path.items[0].id }] },
          },
          include: { progress: true },
        });
        const pid = assignment.progress[0].id;

        // Both writers at once — every interleaving must be safe.
        await Promise.allSettled([
          training.updateProgress(pid, { status: 'COMPLETED' } as never, 'it-admin'),
          training.updateOwnProgress(pid, 'COMPLETED', userId),
        ]);
        const fresh = await prisma.trainingProgress.findUniqueOrThrow({ where: { id: pid } });
        if (fresh.status === 'COMPLETED') {
          // Confirmation survived intact — the old read-then-write bug wiped
          // completedAt/confirmedById here.
          expect(fresh.completedAt).not.toBeNull();
          expect(fresh.confirmedById).toBe('it-admin');
        } else {
          expect(fresh.status).toBe('PENDING_CONFIRMATION');
          await training.updateProgress(pid, { status: 'COMPLETED' } as never, 'it-admin');
        }

        // Once confirmed, the trainee can never unwind it.
        await expect(training.updateOwnProgress(pid, 'IN_PROGRESS', userId)).rejects.toMatchObject({
          response: { code: 'INTERNAL_TRAINING_ALREADY_CONFIRMED' },
        });
        const final = await prisma.trainingProgress.findUniqueOrThrow({ where: { id: pid } });
        expect(final.status).toBe('COMPLETED');
        expect(final.completedAt).not.toBeNull();

        await prisma.trainingAssignment.delete({ where: { id: assignment.id } });
      }
    });
  });
});

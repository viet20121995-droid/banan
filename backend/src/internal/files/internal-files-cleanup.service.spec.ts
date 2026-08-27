import { InternalFilesCleanupService } from './internal-files-cleanup.service';

jest.mock('node:fs/promises', () => ({
  readdir: jest.fn(),
  stat: jest.fn(),
  unlink: jest.fn(),
}));

const fs = jest.requireMock('node:fs/promises') as {
  readdir: jest.Mock;
  stat: jest.Mock;
  unlink: jest.Mock;
};

const NOW = new Date('2026-08-25T03:00:00Z');
const OLD_MTIME = NOW.getTime() - 48 * 3600_000; // past the 24h grace
const FRESH_MTIME = NOW.getTime() - 3600_000; // inside the grace window

const ORPHAN_OLD = `${'a'.repeat(32)}.jpg`;
const REFERENCED_OLD = `${'b'.repeat(32)}.png`;
const ORPHAN_FRESH = `${'c'.repeat(32)}.webp`;
const FOREIGN = 'not-a-private-file.txt';

function makeService(
  referenced: {
    qc?: string[];
    ms?: string[];
    training?: string[];
    qcPdf?: string[];
    msPdf?: string[];
  } = {},
) {
  const prisma = {
    qcEvidence: {
      findMany: jest.fn().mockResolvedValue((referenced.qc ?? []).map((url) => ({ url }))),
    },
    msEvidence: {
      findMany: jest.fn().mockResolvedValue((referenced.ms ?? []).map((url) => ({ url }))),
    },
    trainingMaterial: {
      findMany: jest.fn().mockResolvedValue((referenced.training ?? []).map((url) => ({ url }))),
    },
    qcReportDelivery: {
      findMany: jest
        .fn()
        .mockResolvedValue((referenced.qcPdf ?? []).map((pdfFile) => ({ pdfFile }))),
    },
    msReportDelivery: {
      findMany: jest
        .fn()
        .mockResolvedValue((referenced.msPdf ?? []).map((pdfFile) => ({ pdfFile }))),
    },
  };
  return { svc: new InternalFilesCleanupService(prisma as never), prisma };
}

beforeEach(() => {
  jest.clearAllMocks();
  fs.readdir.mockResolvedValue([ORPHAN_OLD, REFERENCED_OLD, ORPHAN_FRESH, FOREIGN]);
  fs.stat.mockImplementation((path: string) => {
    const mtimeMs = path.includes(ORPHAN_FRESH) ? FRESH_MTIME : OLD_MTIME;
    return Promise.resolve({ mtimeMs });
  });
  fs.unlink.mockResolvedValue(undefined);
});

describe('InternalFilesCleanupService', () => {
  it('removes ONLY old unreferenced private files — referenced, fresh, and foreign files survive', async () => {
    const { svc, prisma } = makeService({ qc: [REFERENCED_OLD] });
    const removed = await svc.removeOrphanFiles(NOW);

    expect(removed).toBe(1);
    expect(fs.unlink).toHaveBeenCalledTimes(1);
    expect(String(fs.unlink.mock.calls[0][0])).toContain(ORPHAN_OLD);
    // Foreign (non-private-name) files are never even stat'd.
    for (const call of fs.stat.mock.calls) {
      expect(String(call[0])).not.toContain(FOREIGN);
    }
    // Reference check queried every table that can hold a file name.
    expect(prisma.qcEvidence.findMany).toHaveBeenCalled();
    expect(prisma.msEvidence.findMany).toHaveBeenCalled();
    expect(prisma.trainingMaterial.findMany).toHaveBeenCalled();
  });

  it('a file referenced by training materials is kept', async () => {
    const { svc } = makeService({ training: [ORPHAN_OLD, REFERENCED_OLD] });
    const removed = await svc.removeOrphanFiles(NOW);
    expect(removed).toBe(0);
    expect(fs.unlink).not.toHaveBeenCalled();
  });

  it('an approval-time report PDF referenced by a delivery row is kept forever', async () => {
    const { svc } = makeService({ qcPdf: [ORPHAN_OLD], msPdf: [REFERENCED_OLD] });
    const removed = await svc.removeOrphanFiles(NOW);
    expect(removed).toBe(0);
    expect(fs.unlink).not.toHaveBeenCalled();
  });

  it('an empty candidate set skips the DB queries entirely', async () => {
    fs.readdir.mockResolvedValue([FOREIGN]);
    const { svc, prisma } = makeService();
    const removed = await svc.removeOrphanFiles(NOW);
    expect(removed).toBe(0);
    expect(prisma.qcEvidence.findMany).not.toHaveBeenCalled();
  });

  it('the cron wrapper swallows sweep errors', async () => {
    fs.readdir.mockRejectedValue(new Error('disk gone'));
    const { svc } = makeService();
    await expect(svc.sweepOrphans()).resolves.toBeUndefined();
  });
});

import { InternalReportDeliveryService } from './internal-report-delivery.service';

/** Immutable snapshot as complete() freezes it onto the delivery row. */
const QC_SNAPSHOT = {
  pdf: { code: 'QC-X', revision: 1 },
  result: {
    outcome: 'PASS',
    overallPercent: 95,
    overallPass: 47,
    overallApplicable: 48,
    sections: [],
  },
  storeName: 'LTT',
  inspectionId: 'insp1',
  code: 'QC-X',
  revision: 1,
  inspectionDateLabel: '20/08/2026',
  inspectorName: 'admin',
  failedItems: [],
  occurredRisks: [],
};

function makeService(opts: {
  delivery?: Partial<{
    id: string;
    inspectionId: string;
    revision: number;
    recipients: string[];
    status: string;
    attempts: number;
    lockedUntil: Date | null;
    reportSnapshot: unknown;
    pdfFile: string | null;
  }>;
  claimCount?: number;
  emailOk?: boolean;
}) {
  const delivery = {
    id: 'd1',
    inspectionId: 'insp1',
    revision: 1,
    recipients: ['operationmanager@banancakes.com', 'ntyen104@gmail.com'],
    status: 'PENDING',
    attempts: 0,
    lockedUntil: null as Date | null,
    reportSnapshot: QC_SNAPSHOT,
    pdfFile: null as string | null,
    ...opts.delivery,
  };
  const qcUpdateMany = jest.fn().mockResolvedValue({ count: opts.claimCount ?? 1 });
  // NOTE: no qcInspection/msAssignment models here AT ALL — the dispatcher
  // must render entirely from the row's reportSnapshot. Any attempt to
  // re-read live data would crash the test.
  const prisma = {
    qcReportDelivery: {
      findUnique: jest.fn().mockResolvedValue(delivery),
      findMany: jest.fn().mockResolvedValue([]),
      updateMany: qcUpdateMany,
    },
    msReportDelivery: {
      findUnique: jest.fn().mockResolvedValue(null),
      findMany: jest.fn().mockResolvedValue([]),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
  };
  const email = { sendInternalReport: jest.fn().mockResolvedValue(opts.emailOk ?? true) };
  const pdf = {
    renderQcReport: jest.fn().mockResolvedValue(Buffer.from('pdf')),
    renderMsReport: jest.fn().mockResolvedValue(Buffer.from('pdf')),
    readStoredPdf: jest.fn().mockReturnValue(null),
  };
  const config = { get: jest.fn().mockReturnValue(undefined) };
  const svc = new InternalReportDeliveryService(
    prisma as never,
    email as never,
    pdf as never,
    config as never,
  );
  return { svc, prisma, email, pdf, qcUpdateMany, delivery };
}

describe('InternalReportDeliveryService QC dispatch', () => {
  it('claims via PROCESSING (with token + lock) then sends and marks SENT', async () => {
    const m = makeService({});
    await m.svc.dispatchQc('insp1', 1);

    // Claim call: status flip to PROCESSING excludes every other worker.
    const claim = m.qcUpdateMany.mock.calls[0][0];
    expect(claim.where.status).toEqual({ in: ['PENDING', 'FAILED'] });
    expect(claim.data.status).toBe('PROCESSING');
    expect(typeof claim.data.claimToken).toBe('string');
    expect(claim.data.lockedUntil).toBeInstanceOf(Date);

    expect(m.email.sendInternalReport).toHaveBeenCalledTimes(1);
    const args = m.email.sendInternalReport.mock.calls[0][0];
    expect(args.to).toEqual(['operationmanager@banancakes.com', 'ntyen104@gmail.com']);
    expect(args.attachment.filename).toContain('.pdf');

    // markResult is guarded on OUR claim token.
    const mark = m.qcUpdateMany.mock.calls.at(-1)[0];
    expect(mark.where.claimToken).toBe(claim.data.claimToken);
    expect(mark.where.status).toBe('PROCESSING');
    expect(mark.data.status).toBe('SENT');
  });

  it('renders from the row snapshot only — the live inspection is NEVER re-read', async () => {
    // The prisma mock has no qcInspection model: a loadQcReportBundle-style
    // re-read would throw. Content must come from reportSnapshot verbatim.
    const m = makeService({});
    await m.svc.dispatchQc('insp1', 1);
    expect(m.email.sendInternalReport).toHaveBeenCalledTimes(1);
    const args = m.email.sendInternalReport.mock.calls[0][0];
    expect(args.subject).toContain('[QC] ĐẠT · LTT · 20/08/2026');
    expect(m.pdf.renderQcReport).toHaveBeenCalledWith(QC_SNAPSHOT.pdf);
  });

  it('attaches the approval-time stored PDF when present — no re-render, evidence deletions moot', async () => {
    const m = makeService({ delivery: { pdfFile: 'cc.pdf' } });
    m.pdf.readStoredPdf.mockReturnValue(Buffer.from('stored-bytes'));
    await m.svc.dispatchQc('insp1', 1);
    expect(m.pdf.readStoredPdf).toHaveBeenCalledWith('cc.pdf');
    expect(m.pdf.renderQcReport).not.toHaveBeenCalled();
    const args = m.email.sendInternalReport.mock.calls[0][0];
    expect(args.attachment.content.toString()).toBe('stored-bytes');
  });

  it('a provider failure marks FAILED (never throws)', async () => {
    const m = makeService({ emailOk: false });
    await m.svc.dispatchQc('insp1', 1);
    const mark = m.qcUpdateMany.mock.calls.at(-1)[0];
    expect(mark.data.status).toBe('FAILED');
  });

  it('a DB error during dispatch is swallowed — fire-and-forget can never crash the process', async () => {
    const m = makeService({});
    m.prisma.qcReportDelivery.findUnique.mockRejectedValueOnce(new Error('db down'));
    await expect(m.svc.dispatchQc('insp1', 1)).resolves.toBeUndefined();
    expect(m.email.sendInternalReport).not.toHaveBeenCalled();
  });

  it('a lost claim sends nothing — two racers produce ONE email', async () => {
    const m = makeService({ claimCount: 0 });
    await m.svc.dispatchQc('insp1', 1);
    expect(m.email.sendInternalReport).not.toHaveBeenCalled();
  });

  it('a LIVE processing claim is left alone — no updateMany, no email', async () => {
    const m = makeService({
      delivery: { status: 'PROCESSING', lockedUntil: new Date(Date.now() + 60_000) },
    });
    await m.svc.dispatchQc('insp1', 1);
    expect(m.qcUpdateMany).not.toHaveBeenCalled();
    expect(m.email.sendInternalReport).not.toHaveBeenCalled();
  });

  it('an EXPIRED processing claim is stolen with a CAS on its old lockedUntil', async () => {
    const oldLock = new Date(Date.now() - 60_000);
    const m = makeService({ delivery: { status: 'PROCESSING', lockedUntil: oldLock } });
    await m.svc.dispatchQc('insp1', 1);
    const claim = m.qcUpdateMany.mock.calls[0][0];
    expect(claim.where).toMatchObject({ status: 'PROCESSING', lockedUntil: oldLock });
    expect(m.email.sendInternalReport).toHaveBeenCalledTimes(1);
  });

  it('an already-SENT delivery is never re-sent', async () => {
    const m = makeService({ delivery: { status: 'SENT' } });
    await m.svc.dispatchQc('insp1', 1);
    expect(m.email.sendInternalReport).not.toHaveBeenCalled();
  });

  it('a revision > 1 uses the "đã cập nhật" subject', async () => {
    const m = makeService({
      delivery: {
        revision: 2,
        reportSnapshot: { ...QC_SNAPSHOT, revision: 2, pdf: { code: 'QC-X', revision: 2 } },
      },
    });
    await m.svc.dispatchQc('insp1', 2);
    expect(m.email.sendInternalReport.mock.calls[0][0].subject).toContain('Kết quả QC đã cập nhật');
  });
});

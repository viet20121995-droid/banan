import { PromotionsService } from './promotions.service';

/**
 * recordUsage is the authoritative campaign-cap enforcement (evaluate only
 * reads counters). A per-campaign advisory lock serialises redemptions of the
 * same campaign in the order tx; these lock the re-check + increment behaviour.
 */
function makeTx(opts: { campaign: Record<string, unknown> | null; userCount?: number }) {
  const executeRaw = jest.fn().mockResolvedValue(1);
  const findUnique = jest.fn().mockResolvedValue(opts.campaign);
  const count = jest.fn().mockResolvedValue(opts.userCount ?? 0);
  const create = jest.fn().mockResolvedValue({});
  const update = jest.fn().mockResolvedValue({});
  const tx = {
    $executeRaw: executeRaw,
    campaign: { findUnique, update },
    campaignRedemption: { count, create },
  };
  return { tx, executeRaw, count, create, update };
}

const svc = () => new PromotionsService({} as never);
const run = (tx: unknown) =>
  svc().recordUsage({
    campaignIds: ['cam1'],
    userId: 'u1',
    orderId: 'o1',
    tx: tx as never,
  });

describe('PromotionsService.recordUsage (authoritative, race-safe)', () => {
  it('takes a per-campaign advisory lock, then records + increments usedCount', async () => {
    const m = makeTx({
      campaign: { usageLimit: 100, perUserLimit: 1, usedCount: 5 },
    });
    await run(m.tx);
    expect(m.executeRaw).toHaveBeenCalledTimes(1);
    expect(m.create).toHaveBeenCalledTimes(1);
    expect(m.update).toHaveBeenCalledWith({
      where: { id: 'cam1' },
      data: { usedCount: { increment: 1 } },
    });
  });

  it('throws CAMPAIGN_LIMIT_REACHED at the global cap (no record)', async () => {
    const m = makeTx({
      campaign: { usageLimit: 100, perUserLimit: null, usedCount: 100 },
    });
    await expect(run(m.tx)).rejects.toMatchObject({
      response: { code: 'CAMPAIGN_LIMIT_REACHED' },
    });
    expect(m.create).not.toHaveBeenCalled();
  });

  it('throws CAMPAIGN_USER_LIMIT when the per-user cap is reached', async () => {
    const m = makeTx({
      campaign: { usageLimit: null, perUserLimit: 1, usedCount: 3 },
      userCount: 1,
    });
    await expect(run(m.tx)).rejects.toMatchObject({
      response: { code: 'CAMPAIGN_USER_LIMIT' },
    });
    expect(m.create).not.toHaveBeenCalled();
  });

  it('skips a campaign that no longer exists without throwing', async () => {
    const m = makeTx({ campaign: null });
    await run(m.tx);
    expect(m.create).not.toHaveBeenCalled();
  });
});

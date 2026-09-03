import type { Prisma } from '@prisma/client';

import { kitchenQueueWhere, vnDayKey } from './kitchen-queue-where';

// 2026-08-30 09:00 VN == 02:00 UTC.
const NOW = new Date('2026-08-30T02:00:00Z');

type Range = { gte?: Date; lt?: Date };
const clausesOf = (w: Prisma.OrderWhereInput) => w.OR as Prisma.OrderWhereInput[];
const range = (c: Prisma.OrderWhereInput, key: 'scheduledFor' | 'createdAt' | 'updatedAt') =>
  c[key] as unknown as Range;

describe('kitchenQueueWhere', () => {
  it('without a date keeps the classic live queue (+ today done when asked)', () => {
    expect(kitchenQueueWhere('k1', {}, NOW)).toEqual({
      kitchenId: 'k1',
      status: 'SENT_TO_KITCHEN',
    });
    const withDone = kitchenQueueWhere('k1', { includeDoneToday: true }, NOW);
    expect(withDone.kitchenId).toBe('k1');
    const clauses = clausesOf(withDone);
    expect(clauses).toHaveLength(2);
    // "Today" starts at VN midnight, not server midnight.
    expect(range(clauses[1], 'updatedAt').gte?.toISOString()).toBe('2026-08-29T17:00:00.000Z');
  });

  it('a past day: that day only — nothing live leaks in', () => {
    const clauses = clausesOf(kitchenQueueWhere('k1', { date: '2026-08-28' }, NOW));
    expect(
      clauses.some((c) => c.status === 'SENT_TO_KITCHEN' && !c.scheduledFor && !c.createdAt),
    ).toBe(false);
    expect(clauses).toHaveLength(3);
    expect(range(clauses[0], 'scheduledFor').gte?.toISOString()).toBe('2026-08-27T17:00:00.000Z');
    expect(range(clauses[0], 'scheduledFor').lt?.toISOString()).toBe('2026-08-28T17:00:00.000Z');
  });

  it('today: the day clauses PLUS every order still live in the kitchen', () => {
    const clauses = clausesOf(kitchenQueueWhere('k1', { date: vnDayKey(NOW) }, NOW));
    expect(clauses).toHaveLength(4);
    expect(clauses[0]).toEqual({ status: 'SENT_TO_KITCHEN' });
  });

  it('a future day: only what is scheduled for it', () => {
    const clauses = clausesOf(kitchenQueueWhere('k1', { date: '2026-09-02' }, NOW));
    expect(clauses).toHaveLength(3);
    expect(range(clauses[0], 'scheduledFor').gte?.toISOString()).toBe('2026-09-01T17:00:00.000Z');
  });

  it('vnDayKey rolls at VN midnight', () => {
    expect(vnDayKey(new Date('2026-08-29T17:30:00Z'))).toBe('2026-08-30');
    expect(vnDayKey(new Date('2026-08-29T16:30:00Z'))).toBe('2026-08-29');
  });
});

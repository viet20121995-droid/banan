import type { Prisma } from '@prisma/client';

import { kitchenQueueWhere, vnDayKey } from './kitchen-queue-where';

// 2026-08-30 09:00 VN == 02:00 UTC.
const NOW = new Date('2026-08-30T02:00:00Z');

type Range = { gte?: Date; lt?: Date };
const clausesOf = (w: Prisma.OrderWhereInput) => w.OR as Prisma.OrderWhereInput[];
const range = (c: Prisma.OrderWhereInput, key: 'scheduledFor' | 'createdAt' | 'updatedAt') =>
  c[key] as unknown as Range;

describe('kitchenQueueWhere', () => {
  it('without a day keeps the classic live queue (+ today done when asked)', () => {
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
    expect(clauses.some((c) => c.status === 'SENT_TO_KITCHEN')).toBe(false);
    expect(clauses).toHaveLength(3);
    expect(range(clauses[0], 'scheduledFor').gte?.toISOString()).toBe('2026-08-27T17:00:00.000Z');
    expect(range(clauses[0], 'scheduledFor').lt?.toISOString()).toBe('2026-08-28T17:00:00.000Z');
  });

  it('today: the day clauses PLUS live work that is overdue or unscheduled — never future', () => {
    const clauses = clausesOf(kitchenQueueWhere('k1', { date: vnDayKey(NOW) }, NOW));
    expect(clauses).toHaveLength(4);
    const liveClause = clauses[0];
    expect(liveClause.status).toBe('SENT_TO_KITCHEN');
    const alt = liveClause.OR as Prisma.OrderWhereInput[];
    expect(alt[0]).toEqual({ scheduledFor: null });
    // Anything scheduled before tomorrow 00:00 VN — an order for 09/09 is
    // NOT on today's board; it appears on 09/09.
    expect(range(alt[1], 'scheduledFor').lt?.toISOString()).toBe('2026-08-30T17:00:00.000Z');
  });

  it('a future day: only what is scheduled (or dispatched) on it', () => {
    const clauses = clausesOf(kitchenQueueWhere('k1', { date: '2026-09-02' }, NOW));
    expect(clauses).toHaveLength(3);
    expect(range(clauses[0], 'scheduledFor').gte?.toISOString()).toBe('2026-09-01T17:00:00.000Z');
  });

  it('a range spanning today: one window from → to, plus the live clause', () => {
    const clauses = clausesOf(
      kitchenQueueWhere('k1', { from: '2026-08-29', to: '2026-09-05' }, NOW),
    );
    expect(clauses).toHaveLength(4);
    expect(range(clauses[1], 'scheduledFor').gte?.toISOString()).toBe('2026-08-28T17:00:00.000Z');
    expect(range(clauses[1], 'scheduledFor').lt?.toISOString()).toBe('2026-09-05T17:00:00.000Z');
  });

  it('a range entirely in the future carries no live clause', () => {
    const clauses = clausesOf(
      kitchenQueueWhere('k1', { from: '2026-09-01', to: '2026-09-07' }, NOW),
    );
    expect(clauses).toHaveLength(3);
  });

  it('vnDayKey rolls at VN midnight', () => {
    expect(vnDayKey(new Date('2026-08-29T17:30:00Z'))).toBe('2026-08-30');
    expect(vnDayKey(new Date('2026-08-29T16:30:00Z'))).toBe('2026-08-29');
  });
});

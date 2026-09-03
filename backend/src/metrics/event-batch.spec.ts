import { parseEventBatch } from './event-batch';

const ok = {
  visitorId: 'visitor-1234567890',
  sessionId: 'session-1234567890',
  events: [{ type: 'page_view', path: '/product/abc?utm=x#top' }],
};

describe('parseEventBatch', () => {
  it('accepts a well-formed batch and strips query/hash from the path', () => {
    const parsed = parseEventBatch(ok);
    expect(parsed?.events[0]).toEqual({
      type: 'page_view',
      path: '/product/abc',
      label: undefined,
      value: undefined,
      device: undefined,
      referrer: undefined,
    });
  });

  it('rejects the whole batch on any bad field (unauthenticated input)', () => {
    expect(parseEventBatch(null)).toBeNull();
    expect(parseEventBatch({ ...ok, visitorId: 'short' })).toBeNull();
    expect(parseEventBatch({ ...ok, events: [] })).toBeNull();
    expect(parseEventBatch({ ...ok, events: Array(26).fill(ok.events[0]) })).toBeNull();
    expect(parseEventBatch({ ...ok, events: [{ type: 'hack', path: '/' }] })).toBeNull();
    expect(
      parseEventBatch({ ...ok, events: [{ type: 'page_view', path: 'no-slash' }] }),
    ).toBeNull();
    expect(
      parseEventBatch({ ...ok, events: [{ type: 'scroll', path: '/', value: 101 }] }),
    ).toBeNull();
    expect(
      parseEventBatch({ ...ok, events: [{ type: 'session_start', path: '/', device: 'tv' }] }),
    ).toBeNull();
  });

  it('keeps scroll depth, device and referrer when valid', () => {
    const parsed = parseEventBatch({
      ...ok,
      events: [
        { type: 'scroll', path: '/', value: 75 },
        { type: 'session_start', path: '/', device: 'mobile', referrer: 'facebook.com' },
      ],
    });
    expect(parsed?.events[0].value).toBe(75);
    expect(parsed?.events[1].device).toBe('mobile');
    expect(parsed?.events[1].referrer).toBe('facebook.com');
  });
});

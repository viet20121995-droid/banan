/** Event types the storefront may report — anything else is rejected. */
export const SITE_EVENT_TYPES = [
  'session_start',
  'page_view',
  'scroll',
  'click',
  'add_to_cart',
  'checkout',
  'order_placed',
] as const;
export type SiteEventType = (typeof SITE_EVENT_TYPES)[number];

export interface SiteEventInput {
  type: SiteEventType;
  path: string;
  label?: string;
  value?: number;
  device?: 'mobile' | 'tablet' | 'desktop';
  referrer?: string;
}

export interface SiteEventBatch {
  visitorId: string;
  sessionId: string;
  events: SiteEventInput[];
}

const ID_RE = /^[\w-]{8,64}$/;
const MAX_EVENTS = 25;

function str(v: unknown, max: number): string | undefined {
  return typeof v === 'string' && v.length > 0 && v.length <= max ? v : undefined;
}

/** Collapse dynamic IDs, especially the capability in public `/track/:id`. */
export function normalizeAnalyticsPath(raw: string): string {
  const path = raw.split('?')[0].split('#')[0];
  for (const prefix of ['track', 'orders', 'product', 'bundles']) {
    if (new RegExp(`^/${prefix}/[^/]+`).test(path)) return `/${prefix}/:id`;
  }
  return path.slice(0, 200);
}

/**
 * Pure, dependency-free validation of a beacon batch. Returns null on ANY
 * violation — an unauthenticated endpoint never guesses at intent. Paths are
 * stored without query strings (an order id or coupon in a URL is not
 * analytics data).
 */
export function parseEventBatch(body: unknown): SiteEventBatch | null {
  if (!body || typeof body !== 'object') return null;
  const b = body as Record<string, unknown>;
  const visitorId = str(b.visitorId, 64);
  const sessionId = str(b.sessionId, 64);
  if (!visitorId || !sessionId || !ID_RE.test(visitorId) || !ID_RE.test(sessionId)) return null;
  if (!Array.isArray(b.events) || b.events.length === 0 || b.events.length > MAX_EVENTS) {
    return null;
  }
  const events: SiteEventInput[] = [];
  for (const raw of b.events) {
    if (!raw || typeof raw !== 'object') return null;
    const e = raw as Record<string, unknown>;
    const type = SITE_EVENT_TYPES.find((t) => t === e.type);
    const rawPath = str(e.path, 300);
    const path = rawPath ? normalizeAnalyticsPath(rawPath) : undefined;
    if (!type || !path || !path.startsWith('/')) return null;
    const label = e.label === undefined ? undefined : str(e.label, 120);
    if (e.label !== undefined && label === undefined) return null;
    let value: number | undefined;
    if (e.value !== undefined) {
      if (
        typeof e.value !== 'number' ||
        !Number.isInteger(e.value) ||
        e.value < 0 ||
        e.value > 100
      ) {
        return null;
      }
      value = e.value;
    }
    let device: SiteEventInput['device'];
    if (e.device !== undefined) {
      if (e.device !== 'mobile' && e.device !== 'tablet' && e.device !== 'desktop') return null;
      device = e.device;
    }
    const referrer = e.referrer === undefined ? undefined : str(e.referrer, 200);
    if (e.referrer !== undefined && referrer === undefined) return null;
    events.push({ type, path, label, value, device, referrer });
  }
  return { visitorId, sessionId, events };
}

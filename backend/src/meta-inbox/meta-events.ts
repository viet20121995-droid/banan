/**
 * Flattens a Messenger / Instagram webhook payload into the two kinds of
 * events the bot acts on. Everything else (reads, deliveries, reactions,
 * `standby` events while another app holds the thread) is dropped.
 *
 * Payload shape: `{ object: 'page' | 'instagram', entry: [{ id, messaging:
 * [{ sender: {id}, recipient: {id}, timestamp, message?: {...} }] }] }`.
 */

export type MetaChannel = 'messenger' | 'instagram';

/** A customer wrote to the Page (or its Instagram account). */
export interface IncomingMessage {
  kind: 'incoming';
  channel: MetaChannel;
  /** Page id (Messenger) or IG business account id (Instagram). */
  pageId: string;
  /** PSID / IGSID — the id we reply to. */
  userId: string;
  mid: string;
  /** Empty when the customer only sent an attachment/sticker. */
  text: string;
  hasAttachment: boolean;
  timestamp: number;
}

/** Something the Page itself sent — by us, a human, or another app (Sapo…). */
export interface PageEcho {
  kind: 'echo';
  channel: MetaChannel;
  pageId: string;
  /** The customer the Page wrote to. */
  userId: string;
  mid: string;
  /** App that sent it; absent for some inbox tools. */
  appId: string | null;
  timestamp: number;
}

export type MetaEvent = IncomingMessage | PageEcho;

interface RawMessaging {
  sender?: { id?: string };
  recipient?: { id?: string };
  timestamp?: number;
  message?: {
    mid?: string;
    text?: string;
    is_echo?: boolean;
    app_id?: number | string;
    attachments?: unknown[];
  };
}

interface RawPayload {
  object?: string;
  entry?: { id?: string; messaging?: RawMessaging[] }[];
}

export function parseMetaWebhook(body: unknown): MetaEvent[] {
  const payload = (body ?? {}) as RawPayload;
  const channel: MetaChannel | null =
    payload.object === 'page' ? 'messenger' : payload.object === 'instagram' ? 'instagram' : null;
  if (!channel || !Array.isArray(payload.entry)) return [];

  const events: MetaEvent[] = [];
  for (const entry of payload.entry) {
    const pageId = entry.id ?? '';
    for (const m of entry.messaging ?? []) {
      const msg = m.message;
      const senderId = m.sender?.id;
      const recipientId = m.recipient?.id;
      if (!msg?.mid || !senderId || !recipientId) continue;
      const timestamp = m.timestamp ?? Date.now();

      if (msg.is_echo) {
        events.push({
          kind: 'echo',
          channel,
          pageId,
          userId: recipientId,
          mid: msg.mid,
          appId: msg.app_id != null ? String(msg.app_id) : null,
          timestamp,
        });
        continue;
      }
      // Instagram delivers the Page's own messages without is_echo on some
      // account setups — never treat the Page as a customer.
      if (senderId === pageId) continue;

      events.push({
        kind: 'incoming',
        channel,
        pageId,
        userId: senderId,
        mid: msg.mid,
        text: (msg.text ?? '').trim(),
        hasAttachment: Array.isArray(msg.attachments) && msg.attachments.length > 0,
        timestamp,
      });
    }
  }
  return events;
}

import { Injectable, Logger } from '@nestjs/common';

import { EmailService } from '../notifications/email.service';

import { ChatTurn, GrokClient } from './grok.client';
import { MetaGraphClient } from './meta-graph.client';
import { HANDOFF_MARKER, MetaInboxKnowledge } from './meta-inbox.knowledge';
import { IncomingMessage, MetaEvent, PageEcho } from './meta-events';

const HOUR = 60 * 60 * 1000;
/** Turns of context sent to Grok per conversation. */
const HISTORY_TURNS = 12;
/** Meta retries undelivered webhooks for hours — don't answer stale messages. */
const MAX_EVENT_AGE_MS = 10 * 60 * 1000;

const FALLBACK_HANDOFF =
  'Dạ em chuyển anh/chị cho nhân viên tiệm, bạn ấy sẽ nhắn lại anh/chị sớm nhất ạ 🙏';

interface Conversation {
  turns: ChatTurn[];
  at: number;
}

/**
 * Grok auto-reply for the Banan Page's Messenger + Instagram inbox.
 *
 * - Off unless META_BOT_ENABLED=true: events are still received and logged,
 *   so the webhook can be verified before the bot speaks to anyone.
 * - Messages a customer sends in a burst are debounced into one reply.
 * - A human (or another inbox app — Sapo, Page inbox…) writing in a thread
 *   silences the bot there for META_BOT_HUMAN_PAUSE_HOURS (default 12), as
 *   does a Grok handoff. Echoes carrying our own META_APP_ID don't count.
 * - State is in memory: a restart just forgets context and pauses.
 */
@Injectable()
export class MetaInboxService {
  private readonly logger = new Logger(MetaInboxService.name);
  private readonly seen = new Map<string, number>();
  private readonly conversations = new Map<string, Conversation>();
  private readonly pausedUntil = new Map<string, number>();
  private readonly pending = new Map<
    string,
    { events: IncomingMessage[]; timer: NodeJS.Timeout }
  >();
  private readonly running = new Map<string, Promise<void>>();

  constructor(
    private readonly grok: GrokClient,
    private readonly graph: MetaGraphClient,
    private readonly knowledge: MetaInboxKnowledge,
    private readonly email: EmailService,
  ) {}

  private get enabled(): boolean {
    return process.env.META_BOT_ENABLED === 'true';
  }

  private get pauseMs(): number {
    return Number(process.env.META_BOT_HUMAN_PAUSE_HOURS ?? 12) * HOUR;
  }

  private get debounceMs(): number {
    return Number(process.env.META_BOT_DEBOUNCE_MS ?? 4000);
  }

  handle(events: MetaEvent[]): void {
    this.prune();
    for (const e of events) {
      if (this.seen.has(e.mid)) continue;
      this.seen.set(e.mid, Date.now());
      if (e.kind === 'echo') this.onEcho(e);
      else this.onIncoming(e);
    }
  }

  isPaused(key: string): boolean {
    return (this.pausedUntil.get(key) ?? 0) > Date.now();
  }

  private onEcho(e: PageEcho): void {
    const ownAppId = process.env.META_APP_ID;
    if (ownAppId && e.appId === ownAppId) return;
    const key = convKey(e);
    this.pausedUntil.set(key, Date.now() + this.pauseMs);
    this.logger.log(`Human/other app replied in ${key} (app ${e.appId ?? '?'}) — bot paused`);
  }

  private onIncoming(e: IncomingMessage): void {
    const key = convKey(e);
    this.logger.log(`Incoming ${key}: ${e.text ? `"${e.text.slice(0, 80)}"` : '[attachment]'}`);
    if (!this.enabled) return;
    if (Date.now() - e.timestamp > MAX_EVENT_AGE_MS) return;
    if (this.isPaused(key)) return;

    const slot = this.pending.get(key);
    if (slot) clearTimeout(slot.timer);
    const events = [...(slot?.events ?? []), e];
    const timer = setTimeout(() => {
      this.pending.delete(key);
      // One reply at a time per conversation.
      const prev = this.running.get(key) ?? Promise.resolve();
      const next = prev
        .then(() => this.respond(key, events))
        .catch((err: Error) => this.logger.error(`Reply to ${key} failed: ${err.message}`))
        .finally(() => {
          if (this.running.get(key) === next) this.running.delete(key);
        });
      this.running.set(key, next);
    }, this.debounceMs);
    this.pending.set(key, { events, timer });
  }

  /** Visible for tests: produce and send one reply for a burst of messages. */
  async respond(key: string, events: IncomingMessage[]): Promise<void> {
    // A human may have stepped in while we were debouncing.
    if (this.isPaused(key)) return;
    const { userId, pageId, channel } = events[events.length - 1];

    const text = events
      .map((e) => e.text || (e.hasAttachment ? '[Khách gửi ảnh/tệp đính kèm]' : ''))
      .filter(Boolean)
      .join('\n');
    const convo = this.conversations.get(key) ?? { turns: [], at: 0 };
    convo.turns.push({ role: 'user', content: text });

    void this.graph.typing(userId);
    const raw = await this.grok.reply(
      await this.knowledge.systemPrompt(),
      convo.turns.slice(-HISTORY_TURNS),
    );
    const handoff = raw === null || raw.includes(HANDOFF_MARKER);
    const reply = raw?.split(HANDOFF_MARKER).join('').trim() || FALLBACK_HANDOFF;

    if (this.isPaused(key)) return;
    const sent = await this.graph.sendText(userId, reply);
    if (sent) convo.turns.push({ role: 'assistant', content: reply });
    convo.turns = convo.turns.slice(-HISTORY_TURNS);
    convo.at = Date.now();
    this.conversations.set(key, convo);

    if (handoff) {
      this.pausedUntil.set(key, Date.now() + this.pauseMs);
      this.logger.warn(`Handoff ${key}${raw === null ? ' (Grok unavailable)' : ''}`);
      await this.alertStaff({
        channel,
        pageId,
        userId,
        turns: convo.turns,
        grokDown: raw === null,
      });
    }
  }

  private async alertStaff(args: {
    channel: string;
    pageId: string;
    userId: string;
    turns: ChatTurn[];
    grokDown: boolean;
  }): Promise<void> {
    const to = process.env.META_BOT_HANDOFF_TO ?? process.env.CONTACT_TO;
    if (!to) return;
    const rows = args.turns
      .map(
        (t) =>
          `<p style="margin:4px 0"><b>${t.role === 'user' ? 'Khách' : 'Bot'}:</b> ${esc(t.content)}</p>`,
      )
      .join('');
    const inbox = `https://business.facebook.com/latest/inbox/all?asset_id=${encodeURIComponent(args.pageId)}`;
    await this.email.sendRaw({
      toEmail: to,
      subject: `[Inbox ${args.channel === 'instagram' ? 'Instagram' : 'Messenger'}] Khách cần nhân viên trả lời`,
      html: `
        <div style="font-family:system-ui,Segoe UI,Roboto,sans-serif;max-width:560px">
          <h2 style="margin:0 0 12px">Bot đã chuyển hội thoại cho nhân viên</h2>
          ${args.grokDown ? '<p style="color:#b42318">Grok không phản hồi — bot gửi câu giữ khách mặc định.</p>' : ''}
          <div style="padding:12px 16px;background:#f7f3ea;border-radius:8px">${rows}</div>
          <p>Trả lời khách tại <a href="${inbox}">Meta Business Suite inbox</a>. Bot tự im trong hội thoại này khi nhân viên đã nhắn.</p>
        </div>`,
    });
  }

  private prune(): void {
    const now = Date.now();
    for (const [mid, at] of this.seen) if (now - at > HOUR) this.seen.delete(mid);
    for (const [key, c] of this.conversations)
      if (now - c.at > 24 * HOUR) this.conversations.delete(key);
    for (const [key, until] of this.pausedUntil) if (until < now) this.pausedUntil.delete(key);
  }
}

function convKey(e: { channel: string; pageId: string; userId: string }): string {
  return `${e.channel}:${e.pageId}:${e.userId}`;
}

function esc(s: string): string {
  return s.replace(
    /[&<>"]/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!,
  );
}

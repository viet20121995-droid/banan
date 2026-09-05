import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { EmailService } from '../notifications/email.service';

/**
 * "Something broke" mail for whoever runs the system: unhandled 5xx from the
 * API, failed background jobs. Deduplicated per signature (one mail an hour
 * for the same problem) and capped per day so a crash loop cannot flood the
 * inbox. Recipients: `OPS_ALERT_RECIPIENTS` (CSV), else `CONTACT_TO`.
 */
@Injectable()
export class OpsAlertService {
  private readonly logger = new Logger(OpsAlertService.name);
  private readonly lastSent = new Map<string, number>();
  private dayKey = '';
  private dayCount = 0;

  static readonly DEDUPE_MS = 60 * 60_000;
  static readonly MAX_PER_DAY = 30;

  constructor(
    private readonly email: EmailService,
    private readonly config: ConfigService,
  ) {}

  recipients(): string[] {
    const raw =
      this.config.get<string>('OPS_ALERT_RECIPIENTS') ??
      this.config.get<string>('CONTACT_TO') ??
      '';
    return raw
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
  }

  /** Returns true when a mail actually went out (false = deduped/capped/no recipients). */
  async alert(signature: string, subject: string, lines: string[]): Promise<boolean> {
    const now = Date.now();
    const today = new Date(now).toISOString().slice(0, 10);
    if (this.dayKey !== today) {
      this.dayKey = today;
      this.dayCount = 0;
      this.lastSent.clear();
    }
    const last = this.lastSent.get(signature);
    if (last != null && now - last < OpsAlertService.DEDUPE_MS) return false;
    if (this.dayCount >= OpsAlertService.MAX_PER_DAY) return false;
    const to = this.recipients();
    if (to.length === 0) {
      this.logger.warn(`ops alert dropped (no OPS_ALERT_RECIPIENTS): ${subject}`);
      return false;
    }
    this.lastSent.set(signature, now);
    this.dayCount++;
    const html =
      `<p><b>${escape(subject)}</b></p><pre style="font:12px/1.4 monospace;white-space:pre-wrap">` +
      lines.map(escape).join('\n') +
      `</pre><p style="color:#888">Banan ops alert · ${new Date(now).toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })}</p>`;
    let sent = false;
    for (const addr of to) {
      sent =
        (await this.email.sendRaw({ toEmail: addr, subject: `[Banan] ${subject}`, html })) || sent;
    }
    return sent;
  }
}

function escape(s: string): string {
  return s.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' })[c] ?? c);
}

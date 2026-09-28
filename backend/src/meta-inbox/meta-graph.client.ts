import { Injectable, Logger } from '@nestjs/common';

/** Messenger caps a text message at 2000 characters. */
const MAX_TEXT = 2000;

/**
 * Sends replies through the Graph API Send endpoint with the Page access
 * token (META_PAGE_ACCESS_TOKEN — a System User token so it doesn't expire).
 * The same endpoint serves Instagram DMs when the IG account is linked to
 * the Page. `messaging_type: RESPONSE` = inside the 24h customer window.
 */
@Injectable()
export class MetaGraphClient {
  private readonly logger = new Logger(MetaGraphClient.name);

  get configured(): boolean {
    return Boolean(process.env.META_PAGE_ACCESS_TOKEN);
  }

  private get base(): string {
    return `https://graph.facebook.com/${process.env.META_GRAPH_VERSION ?? 'v23.0'}`;
  }

  async sendText(userId: string, text: string): Promise<boolean> {
    for (const chunk of splitForMessenger(text)) {
      const ok = await this.post({
        recipient: { id: userId },
        messaging_type: 'RESPONSE',
        message: { text: chunk },
      });
      if (!ok) return false;
    }
    return true;
  }

  /** Best-effort "typing…" bubble while Grok thinks. */
  async typing(userId: string): Promise<void> {
    await this.post({ recipient: { id: userId }, sender_action: 'typing_on' });
  }

  private async post(payload: Record<string, unknown>): Promise<boolean> {
    if (!this.configured) return false;
    try {
      const res = await fetch(`${this.base}/me/messages`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${process.env.META_PAGE_ACCESS_TOKEN}`,
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(15_000),
      });
      if (!res.ok) {
        const body = (await res.json().catch(() => null)) as {
          error?: { message?: string; code?: number };
        } | null;
        this.logger.warn(
          `Graph send failed: HTTP ${res.status} code=${body?.error?.code ?? '?'} ${body?.error?.message ?? ''}`,
        );
        return false;
      }
      return true;
    } catch (e) {
      this.logger.warn(`Graph send failed: ${(e as Error).message}`);
      return false;
    }
  }
}

/** Splits on paragraph / line boundaries so no chunk exceeds Messenger's cap. */
export function splitForMessenger(text: string, max = MAX_TEXT): string[] {
  const chunks: string[] = [];
  let rest = text.trim();
  while (rest.length > max) {
    let cut = rest.lastIndexOf('\n', max);
    if (cut < max / 2) cut = rest.lastIndexOf(' ', max);
    if (cut < max / 2) cut = max;
    chunks.push(rest.slice(0, cut).trim());
    rest = rest.slice(cut).trim();
  }
  if (rest) chunks.push(rest);
  return chunks;
}

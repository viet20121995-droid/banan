import { Injectable, Logger } from '@nestjs/common';

export interface ChatTurn {
  role: 'user' | 'assistant';
  content: string;
}

/**
 * Thin client for xAI's Grok (OpenAI-compatible chat completions). Configure
 * with XAI_API_KEY; XAI_MODEL (default: fast non-reasoning Grok) / XAI_BASE_URL override the defaults. Returns
 * null on any failure so the caller can fall back to a human handoff instead
 * of leaving the customer unanswered.
 */
@Injectable()
export class GrokClient {
  private readonly logger = new Logger(GrokClient.name);

  get configured(): boolean {
    return Boolean(process.env.XAI_API_KEY);
  }

  private get baseUrl(): string {
    return (process.env.XAI_BASE_URL ?? 'https://api.x.ai/v1').replace(/\/$/, '');
  }

  private get model(): string {
    return process.env.XAI_MODEL ?? 'grok-4.20-0309-non-reasoning';
  }

  async reply(systemPrompt: string, history: ChatTurn[]): Promise<string | null> {
    if (!this.configured) return null;
    try {
      const res = await fetch(`${this.baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${process.env.XAI_API_KEY}`,
        },
        body: JSON.stringify({
          model: this.model,
          temperature: 0.3,
          messages: [{ role: 'system', content: systemPrompt }, ...history],
        }),
        signal: AbortSignal.timeout(45_000),
      });
      const body = (await res.json().catch(() => null)) as {
        choices?: { message?: { content?: string } }[];
        error?: { message?: string } | string;
      } | null;
      const text = body?.choices?.[0]?.message?.content?.trim();
      if (!res.ok || !text) {
        const err = typeof body?.error === 'string' ? body.error : body?.error?.message;
        this.logger.warn(`Grok call failed: HTTP ${res.status} ${err ?? ''}`);
        return null;
      }
      return text;
    } catch (e) {
      this.logger.warn(`Grok call failed: ${(e as Error).message}`);
      return null;
    }
  }
}

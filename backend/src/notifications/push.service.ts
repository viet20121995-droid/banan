import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

import { PrismaService } from '../prisma/prisma.service';

import type { NotificationTemplate } from './notification-templates';

/**
 * Push-notification fan-out via Firebase Cloud Messaging (web + mobile).
 * Lazy-initialises the Admin SDK from the service-account JSON pointed to by
 * `FCM_SERVICE_ACCOUNT_PATH`. When that file is absent (e.g. a fresh dev
 * checkout with no Firebase creds) it degrades to a log-only stub so callers
 * keep working. Best-effort: never throws into the caller.
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);
  private messagingClient: admin.messaging.Messaging | null = null;
  private initialised = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  private messaging(): admin.messaging.Messaging | null {
    if (this.initialised) return this.messagingClient;
    this.initialised = true;

    const path = this.config.get<string>('FCM_SERVICE_ACCOUNT_PATH');
    if (!path) {
      this.logger.warn('FCM disabled — FCM_SERVICE_ACCOUNT_PATH not set.');
      return null;
    }
    const abs = resolve(process.cwd(), path);
    if (!existsSync(abs)) {
      this.logger.warn(`FCM disabled — service account not found at ${abs}.`);
      return null;
    }
    try {
      const json = JSON.parse(readFileSync(abs, 'utf8')) as Record<string, unknown>;
      const app = admin.apps.length
        ? admin.app()
        : admin.initializeApp({
            credential: admin.credential.cert(json as admin.ServiceAccount),
          });
      this.messagingClient = app.messaging();
      this.logger.log(`FCM initialised (project ${String(json.project_id)}).`);
    } catch (e) {
      this.logger.error(`FCM init failed: ${(e as Error).message}`);
      this.messagingClient = null;
    }
    return this.messagingClient;
  }

  /** Resolve the click-through URL for a web push from the payload. */
  private linkFor(data?: Record<string, unknown>): string {
    const base = (this.config.get<string>('CUSTOMER_APP_BASE_URL') ?? '').replace(/\/$/, '');
    if (typeof data?.linkPath === 'string' && data.linkPath) {
      const p = data.linkPath.startsWith('/') ? data.linkPath : `/${data.linkPath}`;
      return base + p;
    }
    if (typeof data?.orderId === 'string' && data.orderId) {
      return `${base}/orders/${data.orderId}`;
    }
    return base || '/';
  }

  /** Push to a single user's devices. */
  async pushToUser(
    userId: string,
    template: NotificationTemplate,
    data?: Record<string, unknown>,
  ): Promise<void> {
    const devices = await this.prisma.deviceToken.findMany({
      where: { userId },
      select: { token: true },
    });
    await this.sendToTokens(
      devices.map((d) => d.token),
      template,
      data,
      `user=${userId}`,
    );
  }

  /** Campaign push — every customer's registered devices. */
  async pushBroadcast(
    template: NotificationTemplate,
    data?: Record<string, unknown>,
  ): Promise<void> {
    // Mirror the in-app broadcast audience: only opted-in, active customers.
    // (Without this, customers who turned off marketing — or are disabled —
    // would still receive the campaign push.)
    const devices = await this.prisma.deviceToken.findMany({
      where: {
        user: { role: 'CUSTOMER', marketingOptIn: true, isActive: true },
      },
      select: { token: true },
    });
    await this.sendToTokens(
      devices.map((d) => d.token),
      template,
      data,
      'broadcast',
    );
  }

  /** Multicast helper — batches of 500 (FCM limit) + stale-token pruning. */
  private async sendToTokens(
    tokens: string[],
    template: NotificationTemplate,
    data: Record<string, unknown> | undefined,
    label: string,
  ): Promise<void> {
    try {
      if (tokens.length === 0) return;
      const messaging = this.messaging();
      if (!messaging) {
        this.logger.log(
          `[push:stub] ${label} devices=${tokens.length} ` +
            `title="${template.title}" type=${template.type}`,
        );
        return;
      }

      // FCM data values must be strings.
      const stringData: Record<string, string> = { type: template.type };
      for (const [k, v] of Object.entries(data ?? {})) {
        stringData[k] = typeof v === 'string' ? v : JSON.stringify(v);
      }
      const notification = { title: template.title, body: template.body };
      const webpush = {
        notification,
        fcmOptions: { link: this.linkFor(data) },
      };

      let ok = 0;
      const stale: string[] = [];
      for (let i = 0; i < tokens.length; i += 500) {
        const batch = tokens.slice(i, i + 500);
        const res = await messaging.sendEachForMulticast({
          tokens: batch,
          notification,
          data: stringData,
          webpush,
        });
        ok += res.successCount;
        res.responses.forEach((r, idx) => {
          if (!r.success) {
            const code = r.error?.code ?? '';
            if (
              code.includes('registration-token-not-registered') ||
              code.includes('invalid-registration-token') ||
              code.includes('invalid-argument')
            ) {
              stale.push(batch[idx]);
            }
          }
        });
      }
      if (stale.length > 0) {
        await this.prisma.deviceToken.deleteMany({
          where: { token: { in: stale } },
        });
      }
      this.logger.log(
        `Push ${label} ok=${ok}/${tokens.length}` + (stale.length ? ` pruned=${stale.length}` : ''),
      );
    } catch (err) {
      this.logger.warn(`Push fan-out failed: ${(err as Error).message}`);
    }
  }
}

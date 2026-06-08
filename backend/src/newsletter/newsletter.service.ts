import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { EmailService } from '../notifications/email.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NewsletterService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly email: EmailService,
    private readonly notifications: NotificationsService,
  ) {}

  /// Double opt-in subscribe:
  ///   - Brand-new email → create row, send verify mail, return `{ pending: true }`.
  ///   - Already confirmed → idempotent, no mail, return `{ pending: false }`.
  ///   - Previously unsubscribed → clear `unsubscribedAt`, re-send verify.
  async subscribe(input: {
    email: string;
    fullName?: string;
    source?: string;
  }): Promise<{ pending: boolean; alreadyConfirmed: boolean }> {
    const email = input.email.toLowerCase().trim();
    if (email.endsWith('@banan.local') || email.endsWith('@guest.banan.local')) {
      throw new BadRequestException({
        code: 'INVALID_EMAIL',
        message: 'Email không hợp lệ.',
      });
    }

    const existing = await this.prisma.newsletterSubscriber.findUnique({
      where: { email },
    });

    if (existing?.confirmedAt && !existing.unsubscribedAt) {
      return { pending: false, alreadyConfirmed: true };
    }

    const row = existing
      ? await this.prisma.newsletterSubscriber.update({
          where: { email },
          data: {
            fullName: input.fullName ?? existing.fullName,
            source: input.source ?? existing.source,
            unsubscribedAt: null,
          },
        })
      : await this.prisma.newsletterSubscriber.create({
          data: {
            email,
            fullName: input.fullName,
            source: input.source,
          },
        });

    // Fire-and-forget the verify email; we don't want a Resend hiccup to
    // 500 the form submission.
    void this.sendVerifyMail(row.email, row.fullName, row.unsubscribeToken);

    return { pending: true, alreadyConfirmed: false };
  }

  /// Called from `/newsletter/confirm?token=...` click in the verify email.
  async confirm(token: string): Promise<{ email: string }> {
    const row = await this.prisma.newsletterSubscriber.findUnique({
      where: { unsubscribeToken: token },
    });
    if (!row) {
      throw new NotFoundException({
        code: 'TOKEN_NOT_FOUND',
        message: 'Link đã hết hạn hoặc không hợp lệ.',
      });
    }
    if (row.confirmedAt) return { email: row.email };
    await this.prisma.newsletterSubscriber.update({
      where: { id: row.id },
      data: { confirmedAt: new Date(), unsubscribedAt: null },
    });
    return { email: row.email };
  }

  /// Same token covers unsubscribe — kept tiny so the footer link in
  /// every campaign email works without a separate token system.
  async unsubscribe(token: string): Promise<{ email: string }> {
    const row = await this.prisma.newsletterSubscriber.findUnique({
      where: { unsubscribeToken: token },
    });
    if (!row) {
      throw new NotFoundException({
        code: 'TOKEN_NOT_FOUND',
        message: 'Link không hợp lệ.',
      });
    }
    if (!row.unsubscribedAt) {
      await this.prisma.newsletterSubscriber.update({
        where: { id: row.id },
        data: { unsubscribedAt: new Date() },
      });
    }
    return { email: row.email };
  }

  // ── Merchant-side listing + stats ──────────────────────────────────

  async list(filters: {
    q?: string;
    confirmed?: boolean;
    page?: number;
    perPage?: number;
  }) {
    const page = filters.page ?? 1;
    const perPage = Math.min(filters.perPage ?? 50, 200);
    const where: Prisma.NewsletterSubscriberWhereInput = {
      ...(filters.q && {
        OR: [
          { email: { contains: filters.q, mode: 'insensitive' } },
          { fullName: { contains: filters.q, mode: 'insensitive' } },
        ],
      }),
      ...(filters.confirmed === true && {
        confirmedAt: { not: null },
        unsubscribedAt: null,
      }),
      ...(filters.confirmed === false && { confirmedAt: null }),
    };
    // 4 queries in one transaction — paginated list + filtered count +
    // 3 KPI counts (active / pending / unsubscribed).
    const [items, total, active, pending, unsubscribed] =
      await this.prisma.$transaction([
        this.prisma.newsletterSubscriber.findMany({
          where,
          orderBy: { subscribedAt: 'desc' },
          skip: (page - 1) * perPage,
          take: perPage,
        }),
        this.prisma.newsletterSubscriber.count({ where }),
        this.prisma.newsletterSubscriber.count({
          where: { confirmedAt: { not: null }, unsubscribedAt: null },
        }),
        this.prisma.newsletterSubscriber.count({
          where: { confirmedAt: null, unsubscribedAt: null },
        }),
        this.prisma.newsletterSubscriber.count({
          where: { unsubscribedAt: { not: null } },
        }),
      ]);

    return {
      items,
      meta: { page, perPage, total },
      stats: { active, pending, unsubscribed },
    };
  }

  /// CSV export of ACTIVE subscribers — drives the merchant's external
  /// mailing-tool sync (Mailchimp / Resend Audiences). One header row +
  /// one row per subscriber.
  async exportActiveCsv(): Promise<string> {
    const rows = await this.prisma.newsletterSubscriber.findMany({
      where: { confirmedAt: { not: null }, unsubscribedAt: null },
      orderBy: { subscribedAt: 'desc' },
      select: {
        email: true,
        fullName: true,
        source: true,
        confirmedAt: true,
      },
    });
    const lines = ['email,fullName,source,confirmedAt'];
    for (const r of rows) {
      lines.push(
        [
          csv(r.email),
          csv(r.fullName ?? ''),
          csv(r.source ?? ''),
          csv(r.confirmedAt?.toISOString() ?? ''),
        ].join(','),
      );
    }
    return lines.join('\n');
  }

  /**
   * Send a newsletter campaign by email to the chosen audience — confirmed
   * newsletter subscribers, all opted-in customers, or both (deduped by
   * email) — each with an unsubscribe/manage link. Optionally also fires the
   * in-app + FCM broadcast. Skips a single failed send and keeps going.
   */
  async sendCampaign(input: {
    subject: string;
    body: string;
    imageUrl?: string;
    audience: 'subscribers' | 'customers' | 'both';
    alsoInApp?: boolean;
    sentById?: string;
  }): Promise<{ recipients: number; emailsSent: number; inApp: number }> {
    const apiBase = this.email.apiBaseUrl;
    const appBase = this.email.customerAppBaseUrl;
    const map = new Map<string, { unsubscribe: string }>();

    if (input.audience === 'subscribers' || input.audience === 'both') {
      const subs = await this.prisma.newsletterSubscriber.findMany({
        where: { confirmedAt: { not: null }, unsubscribedAt: null },
        select: { email: true, unsubscribeToken: true },
      });
      for (const s of subs) {
        map.set(s.email.toLowerCase(), {
          unsubscribe:
            `${apiBase}/newsletter/unsubscribe?token=` +
            encodeURIComponent(s.unsubscribeToken),
        });
      }
    }
    if (input.audience === 'customers' || input.audience === 'both') {
      const custs = await this.prisma.user.findMany({
        where: {
          role: 'CUSTOMER',
          marketingOptIn: true,
          isActive: true,
          NOT: [
            { email: { endsWith: '@guest.banan.local' } },
            { email: { startsWith: 'deleted-' } },
          ],
        },
        select: { email: true },
      });
      for (const c of custs) {
        const key = c.email.toLowerCase();
        // Customers manage marketing emails in their account settings.
        if (!map.has(key)) map.set(key, { unsubscribe: `${appBase}/profile` });
      }
    }

    const recipients = [...map.entries()];
    let emailsSent = 0;
    for (const [email, info] of recipients) {
      try {
        await this.email.sendRaw({
          toEmail: email,
          subject: input.subject,
          html: this.renderCampaign(
            input.subject,
            input.body,
            info.unsubscribe,
            input.imageUrl,
          ),
        });
        emailsSent++;
      } catch {
        // Skip one bad address / rate-limit hiccup; keep sending the rest.
      }
    }

    let inApp = 0;
    if (input.alsoInApp) {
      const res = await this.notifications.broadcastToCustomers({
        type: 'newsletter',
        title: input.subject,
        body: input.body,
      });
      inApp = res.recipients;
    }

    // Keep a history row so the merchant can review what was sent.
    await this.prisma.newsletterCampaign.create({
      data: {
        subject: input.subject,
        body: input.body,
        imageUrl: input.imageUrl ?? null,
        audience: input.audience,
        alsoInApp: input.alsoInApp ?? false,
        recipients: recipients.length,
        emailsSent,
        inAppSent: inApp,
        sentById: input.sentById ?? null,
      },
    });

    return { recipients: recipients.length, emailsSent, inApp };
  }

  /** Send a single test email to one address — no history, no broadcast. */
  async sendTest(input: {
    subject: string;
    body: string;
    imageUrl?: string;
    testEmail: string;
  }): Promise<{ ok: boolean }> {
    await this.email.sendRaw({
      toEmail: input.testEmail,
      subject: `[Thử] ${input.subject}`,
      html: this.renderCampaign(
        input.subject,
        input.body,
        `${this.email.customerAppBaseUrl}/profile`,
        input.imageUrl,
      ),
    });
    return { ok: true };
  }

  /** Recent sent campaigns (history) — newest first. */
  listCampaigns(limit = 50) {
    return this.prisma.newsletterCampaign.findMany({
      orderBy: { createdAt: 'desc' },
      take: Math.min(limit, 200),
    });
  }

  private renderCampaign(
    subject: string,
    body: string,
    unsubscribeUrl: string,
    imageUrl?: string,
  ): string {
    const esc = (s: string) =>
      s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    const bodyHtml = esc(body).replace(/\n/g, '<br>');
    const banner =
      imageUrl && imageUrl.trim().length > 0
        ? `<img src="${esc(imageUrl.trim())}" alt="" style="width:100%;max-height:280px;object-fit:cover;border-radius:10px;margin-bottom:16px;">`
        : '';
    return `
      <div style="font-family:'Helvetica Neue',Arial,sans-serif;max-width:560px;margin:0 auto;color:#2b2a22;">
        <div style="font-family:Georgia,serif;font-size:24px;color:#C9405C;font-weight:700;margin-bottom:12px;">Banan</div>
        ${banner}
        <h2 style="color:#1E6A35;margin:0 0 12px 0;">${esc(subject)}</h2>
        <div style="font-size:15px;line-height:1.7;">${bodyHtml}</div>
        <hr style="border:none;border-top:1px solid #eee;margin:24px 0;">
        <p style="color:#9a9388;font-size:12px;">
          Bạn nhận email này vì đã đăng ký nhận tin hoặc là khách hàng của Banan.
          <a href="${unsubscribeUrl}" style="color:#9a9388;">Hủy nhận tin</a>.
        </p>
      </div>
    `;
  }

  // ── Helpers ────────────────────────────────────────────────────────

  private async sendVerifyMail(
    email: string,
    name: string | null,
    token: string,
  ): Promise<void> {
    const url =
      `${this.email.apiBaseUrl}/newsletter/confirm?token=` +
      encodeURIComponent(token);
    const unsubscribeUrl =
      `${this.email.apiBaseUrl}/newsletter/unsubscribe?token=` +
      encodeURIComponent(token);
    const greeting = name ? `Xin chào ${name},` : 'Xin chào,';
    const html = `
      <div style="font-family: 'Helvetica Neue', Arial, sans-serif; max-width: 480px; margin: 0 auto; color: #2b2a22;">
        <h2 style="color:#1E6A35;margin:0 0 12px 0">Cảm ơn bạn đã đăng ký!</h2>
        <p>${greeting}</p>
        <p>Bấm nút bên dưới để xác nhận bạn muốn nhận khuyến mãi & món mới từ Banan:</p>
        <p style="margin: 24px 0">
          <a href="${url}"
             style="background:#1E6A35;color:#fff;padding:12px 22px;border-radius:8px;text-decoration:none;font-weight:600">
            Xác nhận đăng ký
          </a>
        </p>
        <p style="color:#5e5848;font-size:13px">
          Nếu bạn không đăng ký, có thể bỏ qua email này hoặc
          <a href="${unsubscribeUrl}" style="color:#5e5848">hủy đăng ký</a>.
        </p>
      </div>
    `;
    await this.email.sendRaw({
      toEmail: email,
      subject: 'Xác nhận đăng ký nhận tin từ Banan',
      html,
    });
  }
}

/// Escape a CSV cell — wrap in quotes when it contains a comma, quote or
/// newline; double up internal quotes.
function csv(v: string): string {
  if (/[",\n]/.test(v)) return `"${v.replace(/"/g, '""')}"`;
  return v;
}

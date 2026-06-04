import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { EmailService } from '../notifications/email.service';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NewsletterService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly email: EmailService,
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

  // ── Helpers ────────────────────────────────────────────────────────

  private async sendVerifyMail(
    email: string,
    name: string | null,
    token: string,
  ): Promise<void> {
    const url =
      `${this.email.customerAppBaseUrl}/newsletter/confirm?token=` +
      encodeURIComponent(token);
    const unsubscribeUrl =
      `${this.email.customerAppBaseUrl}/newsletter/unsubscribe?token=` +
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

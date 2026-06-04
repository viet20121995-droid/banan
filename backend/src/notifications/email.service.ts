import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Resend } from 'resend';

import type { NotificationTemplate } from './notification-templates';

/**
 * Transactional email via Resend. Mirrors the in-app notification messages
 * so a customer's inbox shows the same journey they'd see in the app.
 *
 * Configure with `RESEND_API_KEY` and `EMAIL_FROM` (e.g.
 * `"Banan <orders@banan.example.com>"`). Without those vars set, the
 * service logs the email payload instead of sending — keeps local dev
 * working without an API key.
 */
@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private readonly client: Resend | null;
  private readonly from: string;
  private readonly customerAppUrl: string;

  constructor(private readonly config: ConfigService) {
    const apiKey = this.config.get<string>('RESEND_API_KEY');
    this.client = apiKey ? new Resend(apiKey) : null;
    this.from =
      this.config.get<string>('EMAIL_FROM') ?? 'Banan <onboarding@resend.dev>';
    this.customerAppUrl =
      this.config.get<string>('CUSTOMER_APP_BASE_URL') ??
      'http://localhost:8081';

    if (!this.client) {
      this.logger.warn(
        'RESEND_API_KEY not set — emails will be logged, not sent.',
      );
    }
  }

  /**
   * Send the same status-change message the customer sees in-app, by email.
   * `data` may carry an `orderId` + `code` so we can render a deep link.
   * Returns silently on failure — emails are best-effort and must never
   * block the order flow.
   */
  async sendOrderStatusEmail(args: {
    toEmail: string;
    toName: string;
    template: NotificationTemplate;
    orderId?: string;
    orderCode?: string;
  }): Promise<void> {
    if (!isRealEmail(args.toEmail)) {
      // Skip guests with synthetic `@banan.local` addresses.
      return;
    }

    const html = renderOrderEmail({
      headline: args.template.title,
      body: args.template.body,
      recipientName: args.toName,
      orderCode: args.orderCode,
      orderUrl: args.orderId
        ? `${this.customerAppUrl}/orders/${args.orderId}`
        : null,
    });
    const subject = args.orderCode
      ? `${args.template.title} · Đơn ${args.orderCode}`
      : args.template.title;

    if (!this.client) {
      this.logger.log(
        `[email dry-run] to=${args.toEmail} subject="${subject}"`,
      );
      return;
    }

    try {
      const result = await this.client.emails.send({
        from: this.from,
        to: args.toEmail,
        subject,
        html,
      });
      if (result.error) {
        this.logger.warn(
          `Resend reported error sending to ${args.toEmail}: ${result.error.message}`,
        );
      }
    } catch (err) {
      this.logger.warn(
        `Failed to send email to ${args.toEmail}: ${(err as Error).message}`,
      );
    }
  }

  /// Send an arbitrary email — used by the newsletter module for the
  /// confirm + welcome message. Same dry-run / log fallback as
  /// [sendOrderStatusEmail] when no API key is configured.
  async sendRaw(args: {
    toEmail: string;
    subject: string;
    html: string;
  }): Promise<void> {
    if (!isRealEmail(args.toEmail)) return;
    if (!this.client) {
      this.logger.log(
        `[email dry-run] to=${args.toEmail} subject="${args.subject}"`,
      );
      return;
    }
    try {
      const result = await this.client.emails.send({
        from: this.from,
        to: args.toEmail,
        subject: args.subject,
        html: args.html,
      });
      if (result.error) {
        this.logger.warn(
          `Resend error to ${args.toEmail}: ${result.error.message}`,
        );
      }
    } catch (err) {
      this.logger.warn(
        `Failed sending to ${args.toEmail}: ${(err as Error).message}`,
      );
    }
  }

  /// Exposed for newsletter — built from CUSTOMER_APP_BASE_URL.
  get customerAppBaseUrl(): string {
    return this.customerAppUrl;
  }
}

/**
 * `@banan.local` emails come from guest-checkout where the customer didn't
 * type an email. They're not deliverable, so skip them.
 */
function isRealEmail(email: string): boolean {
  if (!email) return false;
  if (email.endsWith('@banan.local')) return false;
  if (!email.includes('@')) return false;
  return true;
}

/**
 * Minimal HTML template. Inline-styled so it renders in Gmail / Outlook /
 * Apple Mail without extra CSS plumbing. Brand-friendly Banan rose + cream.
 */
function renderOrderEmail(args: {
  headline: string;
  body: string;
  recipientName: string;
  orderCode?: string;
  orderUrl: string | null;
}): string {
  const ctaButton = args.orderUrl
    ? `<a href="${escapeHtml(args.orderUrl)}"
         style="display:inline-block;padding:12px 28px;background:#C9405C;
                color:#ffffff;text-decoration:none;border-radius:24px;
                font-weight:600;letter-spacing:0.3px;">
        Xem đơn hàng
      </a>`
    : '';

  const orderLine = args.orderCode
    ? `<p style="margin:0 0 16px 0;color:#6B5A52;font-size:14px;">
         Đơn hàng <strong style="color:#3B2A22;">${escapeHtml(args.orderCode)}</strong>
       </p>`
    : '';

  return `<!doctype html>
<html lang="vi">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>${escapeHtml(args.headline)}</title>
</head>
<body style="margin:0;padding:0;background:#FAF6F1;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#3B2A22;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#FAF6F1;padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border:1px solid #E0D7CC;border-radius:12px;overflow:hidden;">
          <tr>
            <td style="padding:32px 32px 8px 32px;">
              <div style="font-family:Georgia,serif;font-size:24px;color:#C9405C;font-weight:700;letter-spacing:-0.3px;">
                Banan
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:8px 32px 8px 32px;">
              <h1 style="margin:0 0 12px 0;font-size:22px;font-weight:700;color:#3B2A22;">
                ${escapeHtml(args.headline)}
              </h1>
              ${orderLine}
              <p style="margin:0 0 12px 0;font-size:15px;line-height:1.5;color:#3B2A22;">
                Xin chào ${escapeHtml(args.recipientName)},
              </p>
              <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#3B2A22;">
                ${escapeHtml(args.body)}
              </p>
              ${ctaButton}
            </td>
          </tr>
          <tr>
            <td style="padding:32px 32px 28px 32px;">
              <hr style="border:none;border-top:1px solid #E0D7CC;margin:0 0 20px 0;" />
              <p style="margin:0 0 6px 0;font-size:12px;color:#6B5A52;">
                Email này được gửi tự động khi đơn hàng của bạn thay đổi trạng thái.
              </p>
              <p style="margin:0;font-size:12px;color:#6B5A52;">
                Cảm ơn bạn đã chọn Banan ♥
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

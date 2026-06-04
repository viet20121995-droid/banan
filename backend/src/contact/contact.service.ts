import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { EmailService } from '../notifications/email.service';

import type { ContactDto } from './dto/contact.dto';

/** Escape user-supplied text before dropping it into the notification HTML. */
function esc(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

@Injectable()
export class ContactService {
  private readonly logger = new Logger(ContactService.name);

  constructor(
    private readonly email: EmailService,
    private readonly config: ConfigService,
  ) {}

  /**
   * Customer support contact form. Emails the submission to the support
   * inbox (CONTACT_TO, falling back to EMAIL_FROM). In dev — with no mail
   * provider configured — EmailService dry-runs and just logs, so the form
   * still "works" end-to-end without external setup.
   */
  async submit(dto: ContactDto): Promise<void> {
    const to =
      this.config.get<string>('CONTACT_TO') ??
      this.config.get<string>('EMAIL_FROM') ??
      '';

    const rows: Array<[string, string | undefined]> = [
      ['Tên', dto.name],
      ['Email', dto.email],
      ['Điện thoại', dto.phone],
      ['Chủ đề', dto.subject],
    ];
    const meta = rows
      .filter(([, v]) => v && v.trim().length > 0)
      .map(
        ([k, v]) =>
          `<tr><td style="padding:4px 12px 4px 0;color:#6b6b6b">${k}</td>` +
          `<td style="padding:4px 0"><b>${esc(v!)}</b></td></tr>`,
      )
      .join('');

    const html = `
      <div style="font-family:system-ui,Segoe UI,Roboto,sans-serif;max-width:560px">
        <h2 style="margin:0 0 12px">Tin nhắn liên hệ mới</h2>
        <table style="border-collapse:collapse;margin-bottom:16px">${meta}</table>
        <div style="white-space:pre-wrap;padding:12px 16px;background:#f7f3ea;border-radius:8px">${esc(
          dto.message,
        )}</div>
      </div>`;

    await this.email.sendRaw({
      toEmail: to,
      subject: `[Liên hệ] ${dto.subject?.trim() || 'Tin nhắn mới'} — ${dto.name}`,
      html,
    });

    // Always log a one-liner so submissions are traceable even in dry-run.
    this.logger.log(
      `Contact form: ${dto.name} <${dto.email}>${dto.phone ? ` (${dto.phone})` : ''}`,
    );
  }
}

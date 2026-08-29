import { ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Report recipients + app URL for the internal ops app. Env-driven with
 * production defaults, parsed in ONE place — controllers/services never
 * hard-code addresses and the frontend can never supply recipients.
 *
 *   QC_REPORT_RECIPIENTS  — QC completion reports. MUST NOT include
 *                           ducnguyen@vestav.com (per ops: that address only
 *                           receives Mystery Shopper results).
 *   MS_REPORT_RECIPIENTS  — Mystery Shopper approval reports.
 *   INTERNAL_APP_URL      — base URL used in report emails' "view" links.
 */

const DEFAULT_QC_RECIPIENTS = ['operationmanager@banancakes.com', 'ntyen104@gmail.com'];
const DEFAULT_MS_RECIPIENTS = [
  'operationmanager@banancakes.com',
  'ntyen104@gmail.com',
  'ducnguyen@vestav.com',
];

/** Per ops: this address receives Mystery Shopper results ONLY — it is
 *  stripped from QC recipients even when an env override sneaks it in. */
const MS_ONLY_RECIPIENT = 'ducnguyen@vestav.com';

function parseCsv(raw: string | undefined, fallback: string[]): string[] {
  if (!raw) return [...fallback];
  const parsed = raw
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.includes('@'));
  return parsed.length > 0 ? parsed : [...fallback];
}

export function qcReportRecipients(config: ConfigService): string[] {
  const parsed = parseCsv(config.get<string>('QC_REPORT_RECIPIENTS'), DEFAULT_QC_RECIPIENTS);
  const filtered = parsed.filter((e) => e.toLowerCase() !== MS_ONLY_RECIPIENT);
  return filtered.length > 0 ? filtered : [...DEFAULT_QC_RECIPIENTS];
}

export function msReportRecipients(config: ConfigService): string[] {
  return parseCsv(config.get<string>('MS_REPORT_RECIPIENTS'), DEFAULT_MS_RECIPIENTS);
}

export function internalAppUrl(config: ConfigService): string {
  const explicit = config.get<string>('INTERNAL_APP_URL');
  if (explicit) return explicit.replace(/\/$/, '');
  const domain = config.get<string>('BASE_DOMAIN');
  return domain ? `https://internal.${domain}` : 'http://localhost:8084';
}

/**
 * Low-score survey alert recipients (`SURVEY_ALERT_RECIPIENTS`, CSV).
 * Deliberately NO built-in default: unset means no alert email is queued
 * (the case is still created) — recipients are ops policy, not code.
 */
export function surveyAlertRecipients(config: ConfigService): string[] {
  return parseCsv(config.get<string>('SURVEY_ALERT_RECIPIENTS'), []);
}

/** SLA (hours) after which an unresolved survey case shows as OVERDUE.
 *  `SURVEY_CASE_SLA_HOURS`, default 48. */
export function surveyCaseSlaHours(config: ConfigService): number {
  const raw = Number(config.get<string>('SURVEY_CASE_SLA_HOURS'));
  return Number.isFinite(raw) && raw > 0 ? raw : 48;
}

/**
 * Shared internal access code for the public MS link generator
 * (`INTERNAL_MS_CREATOR_CODE`). FAIL CLOSED: unset/blank disables the
 * generator everywhere — never a built-in default, never logged.
 */
export function msCreatorCode(config: ConfigService): string {
  const code = config.get<string>('INTERNAL_MS_CREATOR_CODE')?.trim();
  if (!code) {
    throw new ServiceUnavailableException({
      code: 'INTERNAL_MS_CREATOR_DISABLED',
      message: 'Chức năng tạo link chưa được kích hoạt — liên hệ quản trị viên.',
    });
  }
  return code;
}

import { ConfigService } from '@nestjs/config';

import { internalAppUrl, msReportRecipients, qcReportRecipients } from './internal-config';

function config(values: Record<string, string> = {}): ConfigService {
  return { get: (key: string) => values[key] } as never;
}

describe('internal report recipients', () => {
  it('QC defaults NEVER include ducnguyen@vestav.com', () => {
    const to = qcReportRecipients(config());
    expect(to).toEqual(['operationmanager@banancakes.com', 'ntyen104@gmail.com']);
    expect(to).not.toContain('ducnguyen@vestav.com');
  });

  it('MS defaults are exactly the three agreed recipients', () => {
    expect(msReportRecipients(config())).toEqual([
      'operationmanager@banancakes.com',
      'ntyen104@gmail.com',
      'ducnguyen@vestav.com',
    ]);
  });

  it('ducnguyen@vestav.com is stripped from QC even when an env override includes it', () => {
    expect(
      qcReportRecipients(config({ QC_REPORT_RECIPIENTS: 'a@x.com,ducnguyen@vestav.com,b@y.com' })),
    ).toEqual(['a@x.com', 'b@y.com']);
    // Case-insensitive, and an override consisting ONLY of the MS-only
    // address falls back to the QC defaults instead of an empty list.
    expect(qcReportRecipients(config({ QC_REPORT_RECIPIENTS: 'DucNguyen@Vestav.com' }))).toEqual([
      'operationmanager@banancakes.com',
      'ntyen104@gmail.com',
    ]);
  });

  it('env overrides are parsed as CSV; garbage falls back to defaults', () => {
    expect(qcReportRecipients(config({ QC_REPORT_RECIPIENTS: 'a@x.com , b@y.com' }))).toEqual([
      'a@x.com',
      'b@y.com',
    ]);
    expect(qcReportRecipients(config({ QC_REPORT_RECIPIENTS: 'not-an-email' }))).toEqual([
      'operationmanager@banancakes.com',
      'ntyen104@gmail.com',
    ]);
  });

  it('internalAppUrl prefers INTERNAL_APP_URL, then BASE_DOMAIN, then localhost', () => {
    expect(internalAppUrl(config({ INTERNAL_APP_URL: 'https://x.dev/' }))).toBe('https://x.dev');
    expect(internalAppUrl(config({ BASE_DOMAIN: 'banancakes.vn' }))).toBe(
      'https://internal.banancakes.vn',
    );
    expect(internalAppUrl(config())).toBe('http://localhost:8084');
  });
});

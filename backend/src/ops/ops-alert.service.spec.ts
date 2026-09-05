import { OpsAlertService } from './ops-alert.service';

function make(env: Record<string, string | undefined>) {
  const email = { sendRaw: jest.fn().mockResolvedValue(true) };
  const config = { get: (k: string) => env[k] };
  return { svc: new OpsAlertService(email as never, config as never), email };
}

describe('OpsAlertService', () => {
  it('mails every recipient, once per signature per hour', async () => {
    const { svc, email } = make({ OPS_ALERT_RECIPIENTS: 'a@x.vn, b@x.vn' });
    expect(await svc.alert('5xx:GET /a', 'API 500', ['boom'])).toBe(true);
    expect(email.sendRaw).toHaveBeenCalledTimes(2);
    expect(email.sendRaw.mock.calls[0][0]).toMatchObject({
      toEmail: 'a@x.vn',
      subject: '[Banan] API 500',
    });
    // Same problem again within the hour: swallowed.
    expect(await svc.alert('5xx:GET /a', 'API 500', ['boom'])).toBe(false);
    expect(email.sendRaw).toHaveBeenCalledTimes(2);
    // A different problem still goes out.
    expect(await svc.alert('5xx:GET /b', 'API 500', ['other'])).toBe(true);
  });

  it('falls back to CONTACT_TO and drops silently with no recipients', async () => {
    const fallback = make({ CONTACT_TO: 'ops@x.vn' });
    expect(fallback.svc.recipients()).toEqual(['ops@x.vn']);
    const none = make({});
    expect(await none.svc.alert('x', 'y', [])).toBe(false);
    expect(none.email.sendRaw).not.toHaveBeenCalled();
  });

  it('caps the number of mails per day so a crash loop cannot flood the inbox', async () => {
    const { svc, email } = make({ OPS_ALERT_RECIPIENTS: 'a@x.vn' });
    for (let i = 0; i < OpsAlertService.MAX_PER_DAY + 5; i++) {
      await svc.alert(`sig-${i}`, `subject ${i}`, []);
    }
    expect(email.sendRaw).toHaveBeenCalledTimes(OpsAlertService.MAX_PER_DAY);
  });
});

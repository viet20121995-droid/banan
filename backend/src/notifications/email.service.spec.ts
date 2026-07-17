// Resend is mocked so NO real email is ever sent and the (possibly ESM-only)
// SDK is never loaded. `mockSend` is the fake provider send(); jest allows a
// factory to reference an out-of-scope var only when it is `mock`-prefixed.
const mockSend = jest.fn();
jest.mock('resend', () => ({
  Resend: jest.fn().mockImplementation(() => ({ emails: { send: mockSend } })),
}));

import type { ConfigService } from '@nestjs/config';

import { EmailService } from './email.service';
import type { NotificationTemplate } from './notification-templates';

const TPL = (over: Partial<NotificationTemplate> = {}): NotificationTemplate =>
  ({ type: 'order.status', title: 'Đơn đã xác nhận', body: 'Cảm ơn bạn.', ...over }) as never;

function svc(overrides: Record<string, unknown> = {}) {
  const cfg: Record<string, unknown> = {
    CUSTOMER_APP_BASE_URL: 'https://banancakes.vn',
    BASE_DOMAIN: 'banancakes.vn',
    ...overrides,
  };
  const config = { get: (k: string) => cfg[k] } as unknown as ConfigService;
  return new EmailService(config);
}
const configured = () =>
  svc({ RESEND_API_KEY: 're_test_key', EMAIL_FROM: 'Banan <no-reply@banancakes.vn>' });

beforeEach(() => mockSend.mockReset());

describe('EmailService — DRY-RUN (RESEND_API_KEY not set)', () => {
  it('order-status email is NOT sent (logged only)', async () => {
    await svc().sendOrderStatusEmail({ toEmail: 'a@gmail.com', toName: 'A', template: TPL(), orderCode: 'BAN-1' });
    expect(mockSend).not.toHaveBeenCalled();
  });
  it('sendRaw returns false and does not send', async () => {
    const r = await svc().sendRaw({ toEmail: 'a@gmail.com', subject: 'S', html: '<p>x</p>' });
    expect(r).toBe(false);
    expect(mockSend).not.toHaveBeenCalled();
  });
  it('password-reset email is NOT sent', async () => {
    await svc().sendPasswordResetEmail({ toEmail: 'a@gmail.com', toName: 'A', resetUrl: 'https://x/r' });
    expect(mockSend).not.toHaveBeenCalled();
  });
});

describe('EmailService — CONFIGURED (RESEND_API_KEY set)', () => {
  it('order-status: sends from banancakes.vn, code in subject, name + CTA in html', async () => {
    mockSend.mockResolvedValue({ error: null });
    await configured().sendOrderStatusEmail({
      toEmail: 'cust@gmail.com', toName: 'Linh', template: TPL(), orderId: 'o1', orderCode: 'BAN-2026-7',
    });
    expect(mockSend).toHaveBeenCalledTimes(1);
    const a = mockSend.mock.calls[0][0];
    expect(a.from).toContain('banancakes.vn');
    expect(a.to).toBe('cust@gmail.com');
    expect(a.subject).toContain('BAN-2026-7');
    expect(a.html).toContain('Linh');
    expect(a.html).toContain('Xem đơn hàng'); // CTA present when orderId given
    // Public tracking link — a guest opening this email has no session, so
    // /orders/:id (auth-gated) would bounce them to /login.
    expect(a.html).toContain('/track/o1');
  });

  it('order-status: SKIPS synthetic guest @banan.local addresses', async () => {
    await configured().sendOrderStatusEmail({
      toEmail: 'guest+abc@banan.local', toName: 'Guest', template: TPL(),
    });
    expect(mockSend).not.toHaveBeenCalled();
  });

  it('order-status: no CTA when there is no orderId', async () => {
    mockSend.mockResolvedValue({ error: null });
    await configured().sendOrderStatusEmail({ toEmail: 'a@gmail.com', toName: 'A', template: TPL() });
    expect(mockSend.mock.calls[0][0].html).not.toContain('Xem đơn hàng');
  });

  it('order-status: HTML-escapes name/body (no injection)', async () => {
    mockSend.mockResolvedValue({ error: null });
    await configured().sendOrderStatusEmail({
      toEmail: 'a@gmail.com', toName: '<script>x</script>', template: TPL({ body: '<b>z</b>' }), orderCode: 'C1',
    });
    const html = mockSend.mock.calls[0][0].html;
    expect(html).not.toContain('<script>x</script>');
    expect(html).toContain('&lt;script&gt;');
  });

  it('order-status: provider error is swallowed (best-effort, never throws)', async () => {
    mockSend.mockResolvedValue({ error: { message: 'domain not verified' } });
    await expect(
      configured().sendOrderStatusEmail({ toEmail: 'a@gmail.com', toName: 'A', template: TPL() }),
    ).resolves.toBeUndefined();
  });

  it('sendRaw: true on accept, false on provider error, false on thrown', async () => {
    const s = configured();
    mockSend.mockResolvedValueOnce({ error: null });
    expect(await s.sendRaw({ toEmail: 'a@gmail.com', subject: 'S', html: '<p>1</p>' })).toBe(true);
    mockSend.mockResolvedValueOnce({ error: { message: 'rate limited' } });
    expect(await s.sendRaw({ toEmail: 'a@gmail.com', subject: 'S', html: '<p>2</p>' })).toBe(false);
    mockSend.mockRejectedValueOnce(new Error('network down'));
    expect(await s.sendRaw({ toEmail: 'a@gmail.com', subject: 'S', html: '<p>3</p>' })).toBe(false);
  });

  it('sendRaw: synthetic address → false, no send', async () => {
    const r = await configured().sendRaw({ toEmail: 'g@banan.local', subject: 'S', html: 'x' });
    expect(r).toBe(false);
    expect(mockSend).not.toHaveBeenCalled();
  });

  it('password-reset: sends with reset subject and reset URL in html', async () => {
    mockSend.mockResolvedValue({ error: null });
    await configured().sendPasswordResetEmail({
      toEmail: 'a@gmail.com', toName: 'A', resetUrl: 'https://banancakes.vn/reset?token=xyz123',
    });
    const a = mockSend.mock.calls[0][0];
    expect(a.subject).toContain('Đặt lại mật khẩu');
    expect(a.html).toContain('xyz123');
  });

  it('derives apiBaseUrl from BASE_DOMAIN, customerAppBaseUrl from config', () => {
    const s = configured();
    expect(s.apiBaseUrl).toBe('https://api.banancakes.vn/api/v1');
    expect(s.customerAppBaseUrl).toBe('https://banancakes.vn');
  });
});

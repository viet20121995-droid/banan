import { redactBody } from './audit-log.interceptor';

describe('redactBody', () => {
  it('blanks secrets by key name, keeps everything else, trims long strings', () => {
    const out = redactBody({
      email: 'admin@banan.local',
      password: 'hunter2',
      nested: { refreshToken: 'abc', items: [{ qty: 2, secretKey: 'k' }] },
      note: 'x'.repeat(600),
    }) as Record<string, unknown>;
    expect(out.email).toBe('admin@banan.local');
    expect(out.password).toBe('[redacted]');
    expect((out.nested as Record<string, unknown>).refreshToken).toBe('[redacted]');
    expect((out.nested as { items: Array<Record<string, unknown>> }).items[0].secretKey).toBe(
      '[redacted]',
    );
    expect((out.nested as { items: Array<Record<string, unknown>> }).items[0].qty).toBe(2);
    expect((out.note as string).length).toBe(501);
  });

  it('passes primitives and null through', () => {
    expect(redactBody(null)).toBeNull();
    expect(redactBody(3)).toBe(3);
    expect(redactBody(undefined)).toBeUndefined();
  });
});

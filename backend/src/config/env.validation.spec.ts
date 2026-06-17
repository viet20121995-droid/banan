import { validateEnv } from './env.validation';

const good = {
  JWT_ACCESS_SECRET: 'a'.repeat(40),
  JWT_REFRESH_SECRET: 'b'.repeat(40),
};

describe('validateEnv', () => {
  it('passes with real, long secrets', () => {
    expect(() => validateEnv({ ...good })).not.toThrow();
  });

  it('rejects the .env.example placeholder secret', () => {
    expect(() =>
      validateEnv({
        ...good,
        JWT_ACCESS_SECRET: 'replace-me-with-a-long-random-string',
      }),
    ).toThrow(/placeholder/);
  });

  it('rejects a too-short secret', () => {
    expect(() =>
      validateEnv({ ...good, JWT_REFRESH_SECRET: 'short' }),
    ).toThrow(/at least 32/);
  });

  it('rejects a missing secret', () => {
    const { JWT_ACCESS_SECRET, ...rest } = good;
    void JWT_ACCESS_SECRET;
    expect(() => validateEnv(rest)).toThrow(/JWT_ACCESS_SECRET is not set/);
  });
});

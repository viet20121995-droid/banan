/**
 * Fail-fast environment validation, run by ConfigModule at bootstrap.
 *
 * Catches the classic deploy mistake of shipping the `.env.example` JWT
 * placeholders (which are public, so every token would be forgeable) or a
 * too-short secret. Better to refuse to start than to boot insecure.
 */
const PLACEHOLDER = /replace-me/i;
const MIN_SECRET_LEN = 32;

export function validateEnv(config: Record<string, unknown>): Record<string, unknown> {
  const errors: string[] = [];

  for (const key of ['JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET']) {
    const value = config[key];
    if (typeof value !== 'string' || value.length === 0) {
      errors.push(`${key} is not set`);
    } else if (PLACEHOLDER.test(value)) {
      errors.push(`${key} still uses the .env.example placeholder — set a real random secret`);
    } else if (value.length < MIN_SECRET_LEN) {
      errors.push(`${key} must be at least ${MIN_SECRET_LEN} characters`);
    }
  }

  if (errors.length > 0) {
    throw new Error(`Invalid environment configuration:\n - ${errors.join('\n - ')}`);
  }
  return config;
}

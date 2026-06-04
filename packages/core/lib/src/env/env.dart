/// Build-time configuration. Populated from `--dart-define` (or `--dart-define-from-file`).
///
/// Example:
/// ```
/// flutter run --dart-define=BANAN_API_BASE_URL=http://localhost:3000/api/v1
/// ```
class Env {
  const Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'BANAN_API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  static const String wsUrl = String.fromEnvironment(
    'BANAN_WS_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// Public customer-facing app URL — used by merchant / kitchen apps to
  /// build shareable tracking links (`<customerAppUrl>/orders/<id>`).
  static const String customerAppUrl = String.fromEnvironment(
    'BANAN_CUSTOMER_APP_URL',
    defaultValue: 'http://localhost:8081',
  );

  static const String environment = String.fromEnvironment(
    'BANAN_ENV',
    defaultValue: 'dev',
  );

  static const bool enableSentry = bool.fromEnvironment(
    'BANAN_ENABLE_SENTRY',
  );

  static const String sentryDsn = String.fromEnvironment('BANAN_SENTRY_DSN');

  static bool get isProd => environment == 'prod';
  static bool get isDev => environment == 'dev';
}

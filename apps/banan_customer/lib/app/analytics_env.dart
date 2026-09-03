/// Browser facts for the behaviour beacon (device class, traffic source).
/// The real implementation needs `dart:js_interop`; VM builds (tests) get the
/// no-op stub via the conditional export, same pattern as `url_strategy`.
library;

export 'analytics_env_stub.dart' if (dart.library.html) 'analytics_env_web.dart';

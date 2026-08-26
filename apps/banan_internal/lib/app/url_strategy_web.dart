import 'package:flutter_web_plugins/url_strategy.dart';

/// Clean path-based URLs on web (no '#') so deep links resolve correctly.
/// Requires the server to serve index.html for unknown paths (Caddy
/// `try_files {path} /index.html`).
void configureWebUrlStrategy() => usePathUrlStrategy();

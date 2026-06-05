import 'package:flutter_web_plugins/url_strategy.dart';

/// Use clean path-based URLs on web (no '#'). Without this, Flutter web
/// defaults to hash routing, so a direct path link like
/// `/reset-password?token=...` (e.g. from a password-reset email) is ignored
/// and the app falls back to the home route. Requires the server to serve
/// index.html for unknown paths (Caddy `try_files {path} /index.html`).
void configureWebUrlStrategy() => usePathUrlStrategy();

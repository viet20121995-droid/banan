import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('eval')
external JSAny? _jsEval(String code);

/// Plays the order-update chime. The WebAudio synthesis + autoplay-unlock
/// live in `web/index.html` (`window.__bananChime`), so a single
/// AudioContext is resumed on the customer's first interaction. Best-effort,
/// web-only — no-op elsewhere or if audio is still locked.
void playOrderUpdateChime() {
  if (!kIsWeb) return;
  try {
    _jsEval('window.__bananChime && window.__bananChime()');
  } catch (_) {
    // best-effort
  }
}

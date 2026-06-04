import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('eval')
external JSAny? _jsEval(String code);

/// Bridges to the `beforeinstallprompt` capture wired in `web/index.html`.
/// Returns false on non-web or when the browser hasn't offered an install
/// (already installed, unsupported browser, or criteria not yet met).
bool pwaCanInstall() {
  if (!kIsWeb) return false;
  try {
    final r = _jsEval('window.__bananCanInstall === true');
    return r != null && (r.dartify() == true);
  } catch (_) {
    return false;
  }
}

/// Triggers the native "Add to Home screen" / install dialog.
void pwaPromptInstall() {
  if (!kIsWeb) return;
  try {
    _jsEval('window.__bananPromptInstall && window.__bananPromptInstall()');
  } catch (_) {}
}

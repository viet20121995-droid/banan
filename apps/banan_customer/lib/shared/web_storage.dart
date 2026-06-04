import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('eval')
external JSAny? _jsEval(String code);

/// Tiny key/value store backed by `window.localStorage`. Browser-only —
/// returns null and silently no-ops on other platforms so callers can
/// treat persistence as best-effort without platform branching.
String? read(String key) {
  if (!kIsWeb) return null;
  try {
    final r = _jsEval(
      'window.__bananStorageGet ? window.__bananStorageGet("$key") : ""',
    );
    final v = r?.dartify();
    if (v is String && v.isNotEmpty) return v;
    return null;
  } catch (_) {
    return null;
  }
}

void write(String key, String value) {
  if (!kIsWeb) return;
  try {
    // Escape backslashes + double-quotes so the JS literal survives.
    final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    _jsEval(
      'window.__bananStorageSet && window.__bananStorageSet("$key", "$escaped")',
    );
  } catch (_) {
    /* swallow — non-critical */
  }
}

import 'dart:js_interop';

import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/foundation.dart';

@JS('eval')
external JSAny? _jsEval(String code);

/// Reads the language the customer last chose, persisted to
/// `localStorage` by the helpers in `web/index.html`. Returns null when
/// nothing is saved (first visit) or on non-web.
AppLocale? readSavedLocale() {
  if (!kIsWeb) return null;
  try {
    final r = _jsEval('window.__bananGetLocale ? window.__bananGetLocale() : ""');
    final code = r?.dartify();
    if (code == 'en') return AppLocale.en;
    if (code == 'vi') return AppLocale.vi;
    return null;
  } catch (_) {
    return null;
  }
}

/// Persists the chosen language so it survives a page reload.
void saveLocale(AppLocale locale) {
  if (!kIsWeb) return;
  try {
    final code = locale == AppLocale.en ? 'en' : 'vi';
    _jsEval("window.__bananSetLocale && window.__bananSetLocale('$code')");
  } catch (_) {}
}

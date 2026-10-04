import 'dart:convert';
import 'dart:js_interop';

import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@JS('eval')
external JSAny? _jsEval(String code);

/// Reads the language the customer last chose, persisted to
/// `localStorage` by the helpers in `web/index.html`. Returns null when
/// nothing is saved (first visit) or on non-web.
AppLocale? readSavedLocale() {
  if (!kIsWeb) return null;
  try {
    final r =
        _jsEval('window.__bananGetLocale ? window.__bananGetLocale() : ""');
    return AppLocale.tryParse(r?.dartify() as String?);
  } catch (_) {
    return null;
  }
}

/// Persists the chosen language so it survives a page reload.
void saveLocale(AppLocale locale) {
  if (!kIsWeb) return;
  try {
    _jsEval(
      "window.__bananSetLocale && window.__bananSetLocale('${locale.name}')",
    );
  } catch (_) {}
}

/// Loads the catalog dictionary (assets/i18n/catalog.json). A missing or
/// broken file just leaves catalog copy in Vietnamese.
Future<Map<String, Map<String, String>>> loadCatalogTranslations() async {
  try {
    final raw = jsonDecode(
      await rootBundle.loadString('assets/i18n/catalog.json'),
    ) as Map<String, dynamic>;
    return {
      for (final e in raw.entries)
        e.key: {
          for (final t in (e.value as Map<String, dynamic>).entries)
            t.key: t.value as String,
        },
    };
  } catch (_) {
    return const {};
  }
}

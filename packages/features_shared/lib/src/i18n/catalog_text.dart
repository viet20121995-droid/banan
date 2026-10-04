import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_strings.dart';

/// Catalog copy (product descriptions, drink options, size labels, promo
/// names) is stored in Vietnamese only. The customer app ships a dictionary
/// `exact Vietnamese text → {en, ja}` (assets/i18n/catalog.json) and
/// overrides this provider with it at start-up.
final catalogTranslationsProvider =
    Provider<Map<String, Map<String, String>>>((_) => const {});

/// Shows catalog text in the UI language. Keyed by the exact source text, so
/// copy that staff just edited (no entry yet) shows as written instead of a
/// stale translation. Display only: values sent to the API (option picks…)
/// must stay the original Vietnamese.
final catalogTextProvider = Provider<String Function(String)>((ref) {
  final locale = ref.watch(localeProvider);
  if (locale == AppLocale.vi) return (t) => t;
  final dict = ref.watch(catalogTranslationsProvider);
  String one(String t) => dict[t.trim()]?[locale.name] ?? t;
  // Composite labels: '16cm · Mango Shortcake', 'Đường: Ít đường · Đá: Không đá'.
  String part(String t) {
    final hit = dict[t.trim()]?[locale.name];
    if (hit != null) return hit;
    final i = t.indexOf(': ');
    return i < 0 ? t : '${one(t.substring(0, i))}: ${one(t.substring(i + 2))}';
  }

  return (t) {
    final hit = dict[t.trim()]?[locale.name];
    if (hit != null) return hit;
    return t.contains(' · ') ? t.split(' · ').map(part).join(' · ') : part(t);
  };
});

/// [catalogTextProvider] for widgets without a `ref`. They rebuild on a
/// language switch anyway: their parents watch the string table.
String catalogText(BuildContext context, String text) {
  try {
    return ProviderScope.containerOf(context, listen: false)
        .read(catalogTextProvider)(text);
  } catch (_) {
    return text; // no ProviderScope (widget tests) → as stored
  }
}

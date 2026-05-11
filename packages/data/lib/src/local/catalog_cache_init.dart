import 'package:hive_ce_flutter/hive_flutter.dart';

import 'json_cache.dart';

/// One-shot initialization for the customer app's catalog cache. Hides the
/// Hive imports from app code so the customer's pubspec doesn't have to
/// depend on them directly.
///
/// Returns `null` (and stays silent) if Hive can't initialize for any
/// reason — the app degrades gracefully to network-only mode.
Future<JsonCache?> openCatalogCache({String name = 'banan'}) async {
  try {
    await Hive.initFlutter(name);
    final box = await Hive.openBox<String>('banan.catalog_cache');
    return JsonCache(box);
  } catch (_) {
    return null;
  }
}

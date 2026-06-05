import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'app/locale_store.dart';
import 'app/url_strategy.dart'
    if (dart.library.html) 'app/url_strategy_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean path-based URLs on web so deep links (/reset-password?token=...,
  // /product/:id) resolve to the right screen instead of falling back to home.
  configureWebUrlStrategy();
  initLogging();

  // Default every `DateFormat(...)` call (which currently doesn't pass a
  // locale explicitly) to Vietnamese. Without this the Flutter web build
  // falls back to whatever the browser sends — dates would render
  // "Jul 15" instead of "15 thg 7".
  Intl.defaultLocale = 'vi_VN';
  await initializeDateFormatting('vi_VN', null);

  // Hive backs the offline catalog cache. On web this is IndexedDB; on
  // mobile it's app-documents files. Returns null on init failure — we
  // simply lose offline browsing for the session.
  final catalogCache = await openCatalogCache();

  // Restore the language the customer last chose (persisted to
  // localStorage). Falls back to the provider default (Vietnamese).
  final savedLocale = readSavedLocale();

  // Restore the session before the first frame so the router redirect is
  // correct on launch — no flashes of the login screen for already-logged-in users.
  final container = ProviderContainer(
    overrides: [
      if (catalogCache != null)
        catalogCacheProvider.overrideWithValue(catalogCache),
      if (savedLocale != null)
        localeProvider.overrideWith((ref) => savedLocale),
    ],
  );
  await container.read(authRepositoryProvider).bootstrap();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BananCustomerApp(),
    ),
  );
}

import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging();

  // Hive backs the offline catalog cache. On web this is IndexedDB; on
  // mobile it's app-documents files. Returns null on init failure — we
  // simply lose offline browsing for the session.
  final catalogCache = await openCatalogCache();

  // Restore the session before the first frame so the router redirect is
  // correct on launch — no flashes of the login screen for already-logged-in users.
  final container = ProviderContainer(
    overrides: [
      if (catalogCache != null)
        catalogCacheProvider.overrideWithValue(catalogCache),
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

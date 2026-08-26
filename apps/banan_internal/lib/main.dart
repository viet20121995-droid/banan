import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'app/url_strategy.dart'
    if (dart.library.html) 'app/url_strategy_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureWebUrlStrategy();
  initLogging();

  Intl.defaultLocale = 'vi_VN';
  await initializeDateFormatting('vi_VN', null);

  // Restore the session before the first frame so the router redirect is
  // correct on launch (no login flash for a logged-in admin).
  final container = ProviderContainer();
  await container.read(authRepositoryProvider).bootstrap();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BananInternalApp(),
    ),
  );
}

import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'app/url_strategy.dart'
    if (dart.library.html) 'app/url_strategy_web.dart';
import 'features/orders_mgmt/alert_sound.dart';
import 'features/orders_mgmt/merchant_alerts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean path-based URLs on web so deep links resolve to the right screen.
  configureWebUrlStrategy();
  initLogging();

  Intl.defaultLocale = 'vi_VN';
  await initializeDateFormatting('vi_VN', null);

  // The WebAudio chime is web-only; the alert rule itself stays pure.
  final container = ProviderContainer(
    overrides: [merchantChimeProvider.overrideWithValue(playNewOrderChime)],
  );
  await container.read(authRepositoryProvider).bootstrap();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BananMerchantApp(),
    ),
  );
}

import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'app/url_strategy.dart'
    if (dart.library.html) 'app/url_strategy_web.dart';
import 'features/kanban/alert_sound.dart';
import 'features/kanban/kitchen_alerts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean path-based URLs on web so deep links resolve to the right screen.
  configureWebUrlStrategy();
  initLogging();

  Intl.defaultLocale = 'vi_VN';
  await initializeDateFormatting('vi_VN', null);

  // The WebAudio chime is web-only; the alert rule itself stays pure.
  final container = ProviderContainer(
    overrides: [
      kitchenChimeProvider.overrideWithValue(playNewTicketChime),
      // Tickets + MES only — order-journey / merchant notifications belong
      // to other sites even when the same account is used here.
      notificationTypesProvider.overrideWithValue(
        const ['kitchen_new', 'mfg.qc_alert', 'mfg.daily_digest'],
      ),
    ],
  );
  await container.read(authRepositoryProvider).bootstrap();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BananKitchenApp(),
    ),
  );
}

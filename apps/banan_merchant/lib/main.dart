import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging();

  final container = ProviderContainer();
  await container.read(authRepositoryProvider).bootstrap();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BananMerchantApp(),
    ),
  );
}

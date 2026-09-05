import 'package:banan_data/banan_data.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/kanban/kitchen_alerts.dart';
import '../shared/push_registration.dart';
import '../shared/theme/kitchen_theme.dart';
import 'router.dart';

class BananKitchenApp extends ConsumerWidget {
  const BananKitchenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(kitchenRouterProvider);
    // Staff rooms only exist after authentication. Avoid opening an anonymous
    // socket on the login screen just to listen for kitchen tickets.
    if (ref.watch(authSessionProvider).valueOrNull != null) {
      ref.watch(kitchenAlertsProvider);
      // "(3) Bếp Banan" on the browser tab while orders wait.
      setTabTitle(
        'Bếp Banan',
        ref.watch(notificationsControllerProvider.select((s) => s.unread)),
      );
    }
    return MaterialApp.router(
      title: 'Banan Kitchen',
      debugShowCheckedModeBanner: false,
      theme: KitchenTheme.light(),
      darkTheme: KitchenTheme.dark(),
      themeMode: ThemeMode.system,
      // Staff app is Vietnamese.
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: PushRegistrar(child: child ?? const SizedBox.shrink()),
      ),
      routerConfig: router,
    );
  }
}

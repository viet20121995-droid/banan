import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/push_registration.dart';
import 'router.dart';

class BananKitchenApp extends ConsumerWidget {
  const BananKitchenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(kitchenRouterProvider);
    return MaterialApp.router(
      title: 'Banan Kitchen',
      debugShowCheckedModeBanner: false,
      theme: BananTheme.light(),
      darkTheme: BananTheme.dark(),
      themeMode: ThemeMode.system,
      // Staff app is Vietnamese.
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => PushRegistrar(
        child: BananPageBackground(child: child ?? const SizedBox.shrink()),
      ),
      routerConfig: router,
    );
  }
}

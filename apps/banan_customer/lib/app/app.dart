import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/content/cookie_consent.dart';
import '../features/push/push_registration.dart';
import '../shared/realtime_sync.dart';
import 'locale_store.dart';
import 'router.dart';

class BananCustomerApp extends ConsumerWidget {
  const BananCustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(customerRouterProvider);
    // Persist the language whenever the customer switches it.
    ref.listen<AppLocale>(
      localeProvider,
      (_, next) => saveLocale(next),
    );
    final locale = ref.watch(localeProvider).locale;
    return MaterialApp.router(
      title: 'Banan',
      debugShowCheckedModeBanner: false,
      theme: BananTheme.light(),
      darkTheme: BananTheme.dark(),
      // Always render the brand's light theme — ignore the browser/OS dark-mode
      // preference. The storefront is designed light; dark auto-switching washed
      // out product photos and brand colors. (darkTheme kept for a future toggle.)
      themeMode: ThemeMode.light,
      locale: locale,
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Washi + faint seigaiha behind every route (cart, orders,
      // notifications, …) — one consistent kissaten backdrop app-wide.
      builder: (context, child) => RealtimeCatalogSync(
        child: PushRegistrar(
          child: BananPageBackground(
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                // App-wide cookie-consent bar (renders nothing once chosen).
                const CookieConsentBanner(),
              ],
            ),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}

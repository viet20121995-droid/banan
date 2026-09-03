import 'dart:async';

import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/content/cookie_consent.dart';
import '../features/menu/fullmoon_autumn.dart';
import '../features/push/push_registration.dart';
import '../shared/realtime_sync.dart';
import 'analytics.dart';
import 'locale_store.dart';
import 'router.dart';
import 'visit_beacon.dart';

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
      builder: (context, child) => _AnalyticsConsentGate(
        onEnable: () {
          Analytics.start();
          Analytics.pageView(
            router.routerDelegate.currentConfiguration.uri.path,
          );
          unawaited(sendVisitBeacon());
        },
        child: RealtimeCatalogSync(
          child: PushRegistrar(
            child: BananPageBackground(
              child: _CampaignPageBackground(
                // Behaviour beacon: every scroll notification feeds the page's
                // max depth, every pointer-up counts as a click on the current
                // page. Translucent listeners — nothing about input changes.
                child: NotificationListener<ScrollUpdateNotification>(
                  onNotification: (n) {
                    final m = n.metrics;
                    if (m.axis == Axis.vertical && m.hasContentDimensions) {
                      final total = m.maxScrollExtent + m.viewportDimension;
                      if (total > 0) {
                        Analytics.scroll(
                          (m.pixels + m.viewportDimension) / total,
                        );
                      }
                    }
                    return false;
                  },
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerUp: (_) => Analytics.click(),
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
            ),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}

/// Seasonal line-art across the top of every route while the Fullmoon
/// Autumn campaign runs; plain page colour otherwise.
class _CampaignPageBackground extends StatelessWidget {
  const _CampaignPageBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!fullmoonAutumnCampaignEnabled) return child;
    return Stack(
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Image(
              image: AssetImage(fullmoonAutumnPageBackgroundAsset),
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              excludeFromSemantics: true,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Analytics is optional according to the consent banner, so neither the
/// visitor id nor any beacon may be created before the customer opts in.
class _AnalyticsConsentGate extends ConsumerStatefulWidget {
  const _AnalyticsConsentGate({required this.child, required this.onEnable});

  final Widget child;
  final VoidCallback onEnable;

  @override
  ConsumerState<_AnalyticsConsentGate> createState() =>
      _AnalyticsConsentGateState();
}

class _AnalyticsConsentGateState extends ConsumerState<_AnalyticsConsentGate> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(cookieConsentProvider);
    if (!_started && consent == CookieConsent.all) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onEnable());
    }
    return widget.child;
  }
}

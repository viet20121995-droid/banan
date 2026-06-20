import 'package:banan_data/banan_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/bundles/bundle_strip.dart';
import '../features/locations/locations_screen.dart';
import '../features/menu/menu_controller.dart';
import '../features/menu/menu_screen.dart';

/// Realtime catalog sync (M11). Listens for the backend's `catalog.changed` /
/// `config.changed` broadcasts (sent to the `public` room on any merchant
/// write) and invalidates the matching providers, so the customer UI — menu,
/// collections, banners, fees, marketing programs, FAQ/About — refreshes
/// within a second without a manual reload. Works for guests too (the socket
/// connects anonymously). Wrap the app so it's mounted on every route.
class RealtimeCatalogSync extends ConsumerWidget {
  const RealtimeCatalogSync({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider, (_, next) {
      next.whenData((e) {
        switch (e.event) {
          case 'catalog.changed':
            ref.invalidate(menuControllerProvider);
            ref.invalidate(categoriesProvider);
            ref.invalidate(pinnedCategoriesProvider);
            ref.invalidate(homeCollectionsProvider);
            ref.invalidate(homeBannersProvider);
            ref.invalidate(homeThreadsProvider);
            ref.invalidate(homeBundlesProvider);
          case 'config.changed':
            ref.invalidate(displayConfigProvider);
            ref.invalidate(marketingConfigProvider);
            ref.invalidate(faqContentProvider);
            ref.invalidate(aboutContentProvider);
            ref.invalidate(storesListProvider);
        }
      });
    });
    return child;
  }
}

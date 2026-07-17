import 'dart:async';

import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/web_storage.dart' as web_storage;
import '../bundles/bundle_strip.dart';
import '../cart/cart_controller.dart';
import '../checkout/fulfillment_preference.dart';
import '../content/app_footer.dart';
// Used inside the inline _QuickAddSheet defined at the bottom of this file.
// Pulling the import up here keeps all imports grouped at the top.
import '../locations/locations_screen.dart' show storesListProvider;
import '../notifications/notifications_controller.dart';
import '../orders/reorder_helper.dart';
import '../product_detail/cake_wizard.dart';
import '../wishlist/wishlist_controller.dart';
import 'banan_brand.dart';
import 'contact_fab.dart';
import 'menu_controller.dart';
import 'promo_popup_dialog.dart';
import 'pwa_install.dart';
import 'section_header.dart';

/// Merchant-managed hero banners for the home carousel.
final homeBannersProvider = FutureProvider<List<HomeBanner>>((ref) async {
  final res = await ref.watch(bannersRepositoryProvider).publicList();
  return res.when(success: (l) => l, failure: (_) => const []);
});

/// Whether the hero "Đặt hàng ↓" CTA has been used this session. Once the
/// customer taps it (or it's been dismissed) it stays hidden until a fresh
/// page load.
final heroCtaDismissedProvider = StateProvider<bool>((_) => false);

/// Active hashtag filter for the bakery feed (null = show all).
final threadHashtagFilterProvider = StateProvider<String?>((_) => null);

/// Latest published threads — Instagram-style feed above the menu grid.
/// Re-fetches when the hashtag filter changes.
final homeThreadsProvider = FutureProvider<List<Thread>>((ref) async {
  final repo = ref.watch(threadsRepositoryProvider);
  final hashtag = ref.watch(threadHashtagFilterProvider);
  final res = await repo.published(limit: 8, hashtag: hashtag);
  return res.when(
    success: (list) => list,
    failure: (_) => const [],
  );
});

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(menuControllerProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final controller = ref.read(menuControllerProvider.notifier);

    final cart = ref.watch(cartControllerProvider);
    // Watch BOTH the async stream AND the sync currentSession — the
    // StreamProvider can be `AsyncValue.loading` on the first frame after
    // a navigation even when bootstrap already set the session, which
    // would briefly flash the guest UI for an already-authenticated user.
    final asyncSession = ref.watch(authSessionProvider).valueOrNull;
    final syncSession = ref.watch(authRepositoryProvider).currentSession;
    final session = asyncSession ?? syncSession;
    final isGuest = session == null;
    final unread = isGuest
        ? 0
        : ref.watch(notificationsControllerProvider.select((s) => s.unread));

    // Compact the app bar on phones so the brand + actions never overflow.
    final bp = Breakpoint.fromWidth(MediaQuery.sizeOf(context).width);
    final isMobile = bp.isMobile;
    final s = ref.watch(stringsProvider);

    return AppScaffold(
      appBar: AppBar(
        titleSpacing: BananSpacing.md,
        title: InkWell(
          onTap: () => context.go('/'),
          borderRadius: BananRadii.rmd,
          child: BananBrand(compact: isMobile),
        ),
        actions: isMobile
            ? _mobileActions(context, ref, cart: cart, isGuest: isGuest,
                unread: unread,)
            : _desktopActions(context, ref, cart: cart, isGuest: isGuest,
                unread: unread,),
      ),
      // Floating "View cart" button — shows up the moment the cart isn't
      // empty, so the customer can jump straight to checkout without
      // hunting for the icon in the app bar.
      floatingActionButton: cart.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/checkout'),
              icon: const Icon(Icons.shopping_basket_rounded),
              label: Text(s.viewCart(cart.itemCount)),
            ),
      // Single scroll surface: the greeting, fulfillment toggle, search and
      // category chips scroll together with the product grid. This keeps the
      // layout correct at every width (no fixed-height Column / Expanded that
      // can collapse and overlap on wide or short viewports).
      // Stack so the Contact FAB can sit above the page content
      // independently of the standard floatingActionButton slot.
      body: Stack(
        children: [
          _Body(
            state: state,
            onRetry: controller.refresh,
            showHomeContent:
                state.categoryId == null && state.query.isEmpty,
            header: _MenuHeader(
              greeting: isGuest
                  ? null
                  : _GreetingBanner(
                      name: session.user.fullName,
                      micho: session.user.pointsBalance,
                    ),
              fulfillment: _FulfillmentToggle(
                selected: ref.watch(fulfillmentPreferenceProvider),
                onChanged: (next) => ref
                    .read(fulfillmentPreferenceProvider.notifier)
                    .state = next,
              ),
              search: SearchField(
                hint: s.searchHint,
                onChanged: controller.setQuery,
              ),
              chips: categoriesAsync.maybeWhen(
                orElse: () => null,
                data: (categories) => _CategoryChips(
                  categories: categories,
                  selectedId: state.categoryId,
                  onSelect: controller.selectCategory,
                ),
              ),
            ),
          ),
          const ContactFab(),
        ],
      ),
    );
  }

  /// Tablet/desktop: everything inline — there's room.
  List<Widget> _desktopActions(
    BuildContext context,
    WidgetRef ref, {
    required CartState cart,
    required bool isGuest,
    required int unread,
  }) {
    final s = ref.watch(stringsProvider);

    Widget navText(String label, VoidCallback onTap) => TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: Text(label.toUpperCase()),
        );

    return [
      navText(s.locations, () => context.push('/locations')),
      if (!isGuest) navText(s.trackOrders, () => context.push('/orders')),
      if (!isGuest) navText(s.membership, () => context.push('/membership')),
      const SizedBox(width: BananSpacing.sm),
      if (pwaCanInstall())
        IconButton(
          icon: const Icon(Icons.ios_share_rounded),
          tooltip: s.installApp,
          onPressed: pwaPromptInstall,
        ),
      const _LanguageButton(),
      if (!isGuest) _NotificationsButton(unread: unread),
      if (!isGuest)
        IconButton(
          icon: const Icon(Icons.person_rounded),
          tooltip: s.myProfile,
          onPressed: () => context.push('/profile'),
        ),
      _CartButton(itemCount: cart.itemCount),
      if (isGuest) ...[
        TextButton(
          onPressed: () => context.go('/login'),
          child: Text(s.signIn),
        ),
        Padding(
          padding: const EdgeInsets.only(right: BananSpacing.sm),
          child: FilledButton.tonal(
            onPressed: () => context.go('/register'),
            child: Text(s.signUp),
          ),
        ),
      ] else
        Padding(
          padding: const EdgeInsets.only(right: BananSpacing.sm),
          child: TextButton.icon(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(s.signOut),
          ),
        ),
    ];
  }

  /// Mobile: only the cart stays visible; everything else folds into a
  /// single overflow menu so the app bar never overflows on a phone.
  List<Widget> _mobileActions(
    BuildContext context,
    WidgetRef ref, {
    required CartState cart,
    required bool isGuest,
    required int unread,
  }) {
    final s = ref.watch(stringsProvider);
    final activeLocale = ref.watch(localeProvider);
    return [
      _CartButton(itemCount: cart.itemCount),
      PopupMenuButton<String>(
        icon: const Icon(Icons.menu_rounded),
        tooltip: s.language,
        onSelected: (value) {
          switch (value) {
            case 'lang_vi':
              ref.read(localeProvider.notifier).state = AppLocale.vi;
            case 'lang_en':
              ref.read(localeProvider.notifier).state = AppLocale.en;
            case 'install':
              pwaPromptInstall();
            case 'locations':
              context.push('/locations');
            case 'notifications':
              context.push('/notifications');
            case 'profile':
              context.push('/profile');
            case 'addresses':
              context.push('/addresses');
            case 'membership':
              context.push('/membership');
            case 'orders':
              context.push('/orders');
            case 'login':
              context.go('/login');
            case 'register':
              context.go('/register');
            case 'logout':
              ref.read(authControllerProvider.notifier).logout();
          }
        },
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
            value: 'lang_vi',
            checked: activeLocale == AppLocale.vi,
            child: const Text('Tiếng Việt'),
          ),
          CheckedPopupMenuItem(
            value: 'lang_en',
            checked: activeLocale == AppLocale.en,
            child: const Text('English'),
          ),
          const PopupMenuDivider(),
          if (pwaCanInstall())
            PopupMenuItem(
              value: 'install',
              child: ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: Text(s.installApp),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          PopupMenuItem(
            value: 'locations',
            child: ListTile(
              leading: const Icon(Icons.storefront_rounded),
              title: Text(s.locations),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (!isGuest)
            PopupMenuItem(
              value: 'notifications',
              child: ListTile(
                leading: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                title: Text(s.notifications),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!isGuest)
            PopupMenuItem(
              value: 'profile',
              child: ListTile(
                leading: const Icon(Icons.person_rounded),
                title: Text(s.myProfile),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!isGuest)
            PopupMenuItem(
              value: 'addresses',
              child: ListTile(
                leading: const Icon(Icons.place_rounded),
                title: Text(s.myAddresses),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!isGuest)
            PopupMenuItem(
              value: 'membership',
              child: ListTile(
                leading: const Icon(Icons.loyalty_rounded),
                title: Text(s.membership),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!isGuest)
            PopupMenuItem(
              value: 'orders',
              child: ListTile(
                leading: const Icon(Icons.receipt_long_rounded),
                title: Text(s.myOrders),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (isGuest) ...[
            PopupMenuItem(
              value: 'login',
              child: ListTile(
                leading: const Icon(Icons.login_rounded),
                title: Text(s.signIn),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'register',
              child: ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: Text(s.signUp),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ] else
            PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: Text(s.signOut),
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    ];
  }
}

/// Desktop language switcher — a small VI/EN popup in the app bar.
class _LanguageButton extends ConsumerWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(localeProvider);
    return PopupMenuButton<AppLocale>(
      icon: const Icon(Icons.language_rounded),
      tooltip: ref.watch(stringsProvider).language,
      onSelected: (l) => ref.read(localeProvider.notifier).state = l,
      itemBuilder: (_) => [
        for (final l in AppLocale.values)
          CheckedPopupMenuItem(
            value: l,
            checked: active == l,
            child: Text(l.label),
          ),
      ],
    );
  }
}

// Kept around for when proper offline messaging matters; the call-site
// in the menu screen is currently commented out.
// ignore: unused_element
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.cacheUpdatedAt, required this.onRetry});

  final DateTime? cacheUpdatedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = cacheUpdatedAt == null
        ? null
        : _ageLabel(DateTime.now().difference(cacheUpdatedAt!));
    return Container(
      margin: const EdgeInsets.only(bottom: BananSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.md,
        vertical: BananSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: BananColors.warning.withValues(alpha: 0.10),
        border: Border.all(color: BananColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18, color: BananColors.warning),
          const SizedBox(width: BananSpacing.sm),
          Expanded(
            child: Text(
              age == null
                  ? 'Bạn đang offline. Đang hiển thị thực đơn đã tải gần nhất.'
                  : 'Bạn đang offline. Thực đơn đã cũ $age.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  String _ageLabel(Duration d) {
    if (d.inMinutes < 1) return 'vừa xong';
    if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
    if (d.inHours < 24) return '${d.inHours} giờ trước';
    return '${d.inDays} ngày trước';
  }
}

/// Time-aware welcome line + loyalty balance ("Micho"). Shown only to
/// signed-in customers since it needs their name and balance.
class _GreetingBanner extends ConsumerWidget {
  const _GreetingBanner({required this.name, required this.micho});

  final String name;
  final int micho;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final h = DateTime.now().hour;
    final greeting = (h >= 5 && h < 11)
        ? s.greetingMorning(name)
        : (h >= 11 && h < 18)
            ? s.greetingAfternoon(name)
            : s.greetingEvening(name);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.14),
            theme.colorScheme.primary.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting 👋',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  s.earnedMicho(micho),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: BananSpacing.md),
          Container(
            padding: const EdgeInsets.all(BananSpacing.sm),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BananColors.gold.withValues(alpha: 0.18),
            ),
            child: const Icon(
              Icons.local_cafe_rounded,
              color: BananColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Big, friendly Pickup vs Delivery switch shown at the top of the menu.
/// The choice persists for the whole session and pre-selects the matching
/// option at checkout, so the customer only decides once.
class _FulfillmentToggle extends ConsumerWidget {
  const _FulfillmentToggle({
    required this.selected,
    required this.onChanged,
  });

  final FulfillmentType selected;
  final ValueChanged<FulfillmentType> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);

    Widget option({
      required FulfillmentType value,
      required IconData icon,
      required String label,
      required String sub,
    }) {
      final isSelected = selected == value;
      return InkWell(
        onTap: () => onChanged(value),
        borderRadius: BananRadii.rmd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            vertical: BananSpacing.md,
            horizontal: BananSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BananRadii.rmd,
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.16),
                      theme.colorScheme.primary.withValues(alpha: 0.06),
                    ],
                  )
                : null,
            color: isSelected ? null : theme.colorScheme.surface,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (theme.dividerTheme.color ?? Colors.black12),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color:
                          theme.colorScheme.primary.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : theme.colorScheme.outline,
                ),
              ),
              const SizedBox(width: BananSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color:
                            isSelected ? theme.colorScheme.primary : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(sub, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      );
    }

    final pickup = option(
      value: FulfillmentType.pickup,
      icon: Icons.storefront_rounded,
      label: s.pickup,
      sub: s.pickupSub,
    );
    final delivery = option(
      value: FulfillmentType.delivery,
      icon: Icons.pedal_bike_rounded,
      label: s.delivery,
      sub: s.deliverySub,
    );

    // Side-by-side when there's room; stacked on narrow phones so neither
    // card gets squeezed to an unreadable width.
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              pickup,
              const SizedBox(height: BananSpacing.sm),
              delivery,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: pickup),
            const SizedBox(width: BananSpacing.sm),
            Expanded(child: delivery),
          ],
        );
      },
    );
  }
}

class _CartButton extends ConsumerWidget {
  const _CartButton({required this.itemCount});
  final int itemCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _BadgedIcon(
      icon: Icons.shopping_basket_rounded,
      tooltip: ref.watch(stringsProvider).cart,
      count: itemCount,
      onPressed: () => GoRouter.of(context).push('/checkout'),
    );
  }
}

class _NotificationsButton extends ConsumerWidget {
  const _NotificationsButton({required this.unread});
  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _BadgedIcon(
      icon: Icons.notifications_none_rounded,
      tooltip: ref.watch(stringsProvider).notifications,
      count: unread,
      onPressed: () => GoRouter.of(context).push('/notifications'),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({
    required this.icon,
    required this.tooltip,
    required this.count,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: const BoxDecoration(
                color: BananColors.primary,
                borderRadius: BananRadii.rPill,
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Capped at THREE rows that scroll horizontally together — keeps the
    // category bar tidy on tablet / mobile (where a plain Wrap spilled onto
    // many rows and pushed the menu down). Chips are distributed round-robin
    // across the 3 rows so the rows stay balanced; the whole block scrolls as
    // one. On wide screens it simply doesn't need to scroll.
    final chips = <Widget>[
      _Chip(
        label: ref.watch(stringsProvider).all,
        selected: selectedId == null,
        onTap: () => onSelect(null),
      ),
      ...categories.map(
        (c) => _Chip(
          label: c.name,
          selected: selectedId == c.id,
          onTap: () => onSelect(c.id),
        ),
      ),
    ];
    final rows = <List<Widget>>[[], [], []];
    for (var i = 0; i < chips.length; i++) {
      rows[i % 3].add(chips[i]);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var ri = 0; ri < rows.length; ri++)
            if (rows[ri].isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  bottom: ri < rows.length - 1 ? BananSpacing.sm : 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final chip in rows[ri])
                      Padding(
                        padding: const EdgeInsets.only(right: BananSpacing.sm),
                        child: chip,
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Stacks the greeting / fulfillment / search / chips with consistent
/// spacing. Scrolls together with the grid as the first sliver.
class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.fulfillment,
    required this.search,
    this.greeting,
    this.chips,
  });

  final Widget? greeting;
  final Widget fulfillment;
  final Widget search;
  final Widget? chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (greeting != null) ...[
          greeting!,
          const SizedBox(height: BananSpacing.md),
        ],
        // Network-wide pause banner — surfaces an alert when any branch is
        // currently paused so the customer sees it before adding to cart.
        const _PausedStatusBanner(),
        fulfillment,
        const SizedBox(height: BananSpacing.md),
        search,
        if (chips != null) ...[
          const SizedBox(height: BananSpacing.md),
          chips!,
        ],
        const SizedBox(height: BananSpacing.lg),
      ],
    );
  }
}

/// Banner shown at the top of the menu when at least one branch has paused
/// pickup or delivery. Stays out of the way (nothing rendered) when every
/// branch is operating normally.
class _PausedStatusBanner extends ConsumerWidget {
  const _PausedStatusBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores =
        ref.watch(storesListProvider).valueOrNull ?? const <Store>[];
    final paused = stores
        .where((s) => s.isPaused || s.isPickupPaused || s.isDeliveryPaused)
        .toList();
    if (paused.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.md),
      child: _PausedBannerBody(paused: paused, total: stores.length),
    );
  }
}

class _PausedBannerBody extends StatelessWidget {
  const _PausedBannerBody({required this.paused, required this.total});
  final List<Store> paused;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allDown = paused.length >= total && total > 0 &&
        paused.every((s) => s.isPaused);
    final bg = (allDown
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.tertiaryContainer);
    final fg = (allDown
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onTertiaryContainer);

    String channelLabel(Store s) {
      if (s.isPaused) return 'tạm dừng nhận đơn';
      final parts = <String>[];
      if (s.isPickupPaused) parts.add('tự lấy');
      if (s.isDeliveryPaused) parts.add('giao hàng');
      return 'tạm dừng ${parts.join(' + ')}';
    }

    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: bg.withValues(alpha: 0.8),
        border: Border.all(color: bg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: fg, size: 20),
          const SizedBox(width: BananSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allDown
                      ? 'Toàn hệ thống đang tạm ngừng nhận đơn'
                      : 'Một số chi nhánh đang tạm dừng',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                for (final s in paused)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '• ${s.name}: ${channelLabel(s)}'
                      '${(s.pauseReason?.isNotEmpty ?? false) ? ' — ${s.pauseReason}' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(color: fg),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({
    required this.state,
    required this.onRetry,
    required this.showHomeContent,
    required this.header,
  });

  final MenuState state;
  final Future<void> Function() onRetry;
  final bool showHomeContent;
  final Widget header;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _scrollCtrl = ScrollController();
  bool _popupShown = false;

  @override
  void initState() {
    super.initState();
    // Show the admin's promo popup once the first frame settles — never
    // during build so we don't fight with route transitions.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPopup());
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Fetches the promo popup config; if active + version > last-seen,
  /// opens a dialog with the admin's content + optional countdown.
  Future<void> _maybeShowPopup() async {
    if (_popupShown || !mounted) return;
    _popupShown = true;
    final res = await ref.read(promoPopupApiProvider).get();
    if (!mounted) return;
    final popup = res.when(
      success: (p) => p,
      failure: (_) => null,
    );
    if (popup == null) return;

    final lastSeen = _readLastSeenVersion();
    if (!popup.shouldShow(lastSeenVersion: lastSeen)) return;

    await PromoPopupDialog.show(context, popup);
    if (!mounted) return;
    _writeLastSeenVersion(popup.version);
  }

  /// localStorage-backed version tracker. Browser-only — Hive could back
  /// this on mobile later. Returns null on first visit.
  int? _readLastSeenVersion() {
    try {
      final v = web_storage.read(_lastSeenKey);
      return v == null ? null : int.tryParse(v);
    } catch (_) {
      return null;
    }
  }

  void _writeLastSeenVersion(int v) {
    try {
      web_storage.write(_lastSeenKey, v.toString());
    } catch (_) {
      /* swallow — non-critical */
    }
  }

  static const _lastSeenKey = 'banan.promoPopup.lastSeenVersion';

  /// One-tap add from the menu grid. Delegates to the top-level helper so
  /// the carousel strips at the top of the page can share the exact same
  /// flow (variant picker sheet + cart confirm snackbar).
  Future<void> _quickAdd(BuildContext context, Product p) =>
      quickAddToCart(context: context, ref: ref, product: p);

  /// Smooth-scrolls past the hero banner so the menu lands at the top —
  /// drives the Domino's-style "Đặt hàng ↓" call to action.
  void _scrollToMenu() {
    final target = MediaQuery.sizeOf(context).width < 700 ? 240.0 : 360.0;
    _scrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final showHomeContent = widget.showHomeContent;
    final onRetry = widget.onRetry;
    final header = widget.header;
    final s = ref.watch(stringsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final crossAxis = switch (Breakpoint.fromWidth(width)) {
      Breakpoint.xs => 2,
      Breakpoint.sm => 2,
      Breakpoint.md => 3,
      Breakpoint.lg => 4,
      Breakpoint.xl => 4,
    };

    final loadingFirst = state.loading && state.products.isEmpty;
    final errored = state.failure != null && state.products.isEmpty;
    final emptyResult =
        state.loaded && state.products.isEmpty && !showHomeContent;

    Widget filler(Widget child) => SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: child),
        );

    // On the home view the pinned-category strips (e.g. the Birthday strip)
    // already feature their products, so drop those from the "Tất cả bánh" grid
    // below — otherwise every product in a pinned category renders twice. When a
    // category filter / search is active the strips are hidden, so the grid
    // keeps the full result set.
    final pinned = showHomeContent
        ? ref.watch(pinnedCategoriesProvider).valueOrNull
        : null;
    final pinnedIds = (pinned == null || pinned.isEmpty)
        ? const <String>{}
        : {for (final c in pinned) for (final p in c.products) p.id};
    final gridProducts = pinnedIds.isEmpty
        ? state.products
        : state.products.where((p) => !pinnedIds.contains(p.id)).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await onRetry();
        ref.invalidate(homeThreadsProvider);
      },
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          if (showHomeContent) ...[
            SliverToBoxAdapter(
              child: _HeroCarousel(onOrderTap: _scrollToMenu),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: BananSpacing.sm),
                child: WashiDivider(),
              ),
            ),
          ],
          SliverToBoxAdapter(child: header),
          if (loadingFirst)
            filler(const CircularProgressIndicator())
          else if (errored)
            filler(
              ErrorState(
                message: authFailureMessage(state.failure!),
                onRetry: onRetry,
              ),
            )
          else if (emptyResult)
            filler(
              EmptyState(
                title: s.noCakesTitle,
                message: s.noCakesMsg,
              ),
            )
          else ...[
            if (showHomeContent) ...[
              const SliverToBoxAdapter(child: _OrderAgainStrip()),
              SliverToBoxAdapter(child: _ThreadsStrip()),
              const SliverToBoxAdapter(child: BundleStrip()),
              const SliverToBoxAdapter(child: AllBundlesStrip()),
              SliverToBoxAdapter(child: _PinnedCategories()),
            ],
            if (showHomeContent &&
                state.loaded &&
                gridProducts.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: BananSpacing.lg),
                  child: SectionHeader(
                    overline: 'Thực đơn',
                    title: s.allCakes,
                    subtitle:
                        'Mỗi mẻ bánh ra lò tươi mỗi ngày trong các cửa hàng Banan.',
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: BananSpacing.lg),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxis,
                  crossAxisSpacing: BananSpacing.lg,
                  mainAxisSpacing: BananSpacing.lg,
                  childAspectRatio: 0.75,
                ),
                itemCount: gridProducts.length,
                itemBuilder: (context, i) {
                  final p = gridProducts[i];
                  final session = ref.watch(authSessionProvider).valueOrNull;
                  final wishlistAsync = ref.watch(wishlistIdsProvider);
                  final showStock = ref
                          .watch(displayConfigProvider)
                          .valueOrNull
                          ?.showStockToCustomers ??
                      false;
                  return ProductCard(
                    name: p.name,
                    imageUrl: p.coverImage,
                    tagline: p.description,
                    tags: p.tags,
                    minPrice: p.minPrice,
                    hasPriceRange: p.hasPriceRange,
                    seasonal: p.isSeasonal,
                    averageRating: p.averageRating,
                    reviewCount: p.reviewCount,
                    stockRemaining: showStock ? p.totalLimitedStock : null,
                    soldOut: showStock && p.isSoldOut,
                    isWishlisted: isWishlisted(wishlistAsync, p.id),
                    onToggleWishlist: session == null
                        ? null
                        : () => ref
                            .read(wishlistIdsProvider.notifier)
                            .toggle(p.id),
                    onTap: () => context.push('/product/${p.id}'),
                    onQuickAdd: (showStock && p.isSoldOut)
                        ? null
                        : () => _quickAdd(context, p),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: _NewsletterFooter()),
            const SliverToBoxAdapter(child: AppFooter()),
          ],
        ],
      ),
    );
  }
}

/// Auto-advancing promo banner at the top of the home page, with a big
/// "Đặt hàng ↓" call-to-action that scrolls down to the menu (Domino's-style).
class _HeroCarousel extends ConsumerStatefulWidget {
  const _HeroCarousel({required this.onOrderTap});
  final VoidCallback onOrderTap;

  @override
  ConsumerState<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends ConsumerState<_HeroCarousel> {
  final _ctrl = PageController();
  Timer? _timer;
  int _page = 0;
  int _count = 1;

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _ensureTimer(int count) {
    _count = count;
    if (count <= 1) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= _newTimer();
  }

  /// Re-creates the auto-advance timer. Called both on first build and
  /// whenever the customer manually navigates, so the next auto-tick
  /// always lands `_autoAdvance` after the last interaction (not mid-way).
  void _restartTimer() {
    _timer?.cancel();
    if (_count <= 1) return;
    _timer = _newTimer();
  }

  Timer _newTimer() {
    return Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      final next = (_page + 1) % _count;
      _ctrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _go(int delta) {
    if (!_ctrl.hasClients || _count <= 1) return;
    final next = (_page + delta) % _count;
    _ctrl.animateToPage(
      next < 0 ? next + _count : next,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final ctaDismissed = ref.watch(heroCtaDismissedProvider);
    final width = MediaQuery.sizeOf(context).width;
    final height = width < 700 ? 220.0 : 360.0;

    // Prefer merchant-managed banners; otherwise fall back to promo posts;
    // finally a branded slide so the hero is never empty.
    final banners = ref.watch(homeBannersProvider).valueOrNull ?? const [];
    final threads = ref.watch(homeThreadsProvider).valueOrNull ?? const [];
    final slides = <({String? image, String title})>[
      if (banners.isNotEmpty)
        for (final b in banners)
          (image: b.imageUrl, title: b.title ?? '')
      else ...[
        for (final t in threads)
          if (t.gallery.isNotEmpty)
            (image: t.gallery.first, title: t.title),
      ],
    ];
    if (slides.isEmpty) {
      slides.add((image: null, title: 'Banan Fukuoka Saigon'));
    }
    _ensureTimer(slides.length);
    final title = slides[_page.clamp(0, slides.length - 1)].title;

    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.lg),
      child: ClipRRect(
        borderRadius: BananRadii.rlg,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _ctrl,
                itemCount: slides.length,
                onPageChanged: (i) {
                  setState(() => _page = i);
                  // Reset the auto-advance timer when the customer
                  // manually navigates — feels more natural than fighting
                  // the auto-cycle the moment they tap an arrow.
                  _restartTimer();
                },
                itemBuilder: (_, i) {
                  final slide = slides[i];
                  // Cross-fade each slide between its base gradient and
                  // the image. PageView's default horizontal swipe is
                  // kept — this just adds a softer fade-in once the
                  // page has settled.
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: DecoratedBox(
                      key: ValueKey(slide.image ?? 'slide-$i'),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                      child: slide.image == null
                          ? const SizedBox.expand()
                          : Image.network(
                              slide.image!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.expand(),
                            ),
                    ),
                  );
                },
              ),
              // Dark scrim so the white CTA + title always read well.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black26, Colors.black54],
                  ),
                ),
              ),
              // Decorative wave + kanji accents removed for a cleaner
              // banner — peach-cream theme reads softer without them.
              Padding(
                // Hug the top edge so the CTA sits high on the banner rather
                // than centred (small top inset keeps it off the very edge).
                padding: const EdgeInsets.fromLTRB(
                  BananSpacing.xl,
                  BananSpacing.md,
                  BananSpacing.xl,
                  BananSpacing.xl,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty) ...[
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        // Lora ships weights 400–700 only. Requesting w800 here
                        // made Flutter web synthesize a faux-bold, which dropped
                        // Vietnamese diacritics ("Khuyến mãi" → "Khuyen mai").
                        // w700 is Lora's real heaviest face — full VN subset.
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          shadows: const [
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
                      ),
                      if (!ctaDismissed)
                        const SizedBox(height: BananSpacing.md),
                    ],
                    if (!ctaDismissed)
                      FilledButton.icon(
                        onPressed: () {
                          ref
                              .read(heroCtaDismissedProvider.notifier)
                              .state = true;
                          widget.onOrderTap();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: theme.colorScheme.primary,
                          // ~30% larger than the default CTA (padding + text).
                          padding: const EdgeInsets.symmetric(
                            horizontal: BananSpacing.xl * 1.3,
                            vertical: BananSpacing.md * 1.3,
                          ),
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize:
                                (theme.textTheme.titleMedium?.fontSize ?? 16) *
                                    1.3,
                          ),
                        ),
                        icon: const Icon(
                          Icons.expand_more_rounded,
                          size: 31,
                        ),
                        label: Text(s.orderNow),
                      ),
                  ],
                ),
              ),
              if (slides.length > 1) ...[
                // Prev / next arrows — visible only when there's more
                // than one slide. Translucent circle so they sit on top
                // of any background image without competing with text.
                Positioned(
                  left: BananSpacing.sm,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _CarouselArrow(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Banner trước',
                      onTap: () => _go(-1),
                    ),
                  ),
                ),
                Positioned(
                  right: BananSpacing.sm,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _CarouselArrow(
                      icon: Icons.chevron_right_rounded,
                      tooltip: 'Banner kế tiếp',
                      onTap: () => _go(1),
                    ),
                  ),
                ),
                // Dot indicators — also tappable as quick page-jumps.
                Positioned(
                  bottom: BananSpacing.sm,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < slides.length; i++)
                        GestureDetector(
                          onTap: () {
                            _ctrl.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 380),
                              curve: Curves.easeInOutCubic,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                            width: i == _page ? 18 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 3,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: i == _page
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small floating chevron button used at the left/right edges of the
/// hero carousel. Semi-transparent so it doesn't compete with the slide
/// image, but solid enough to remain tappable on busy backgrounds.
class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        iconSize: 22,
        color: Colors.white,
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: onTap,
      ),
    );
  }
}

/// Instagram-style bakery feed. Hidden if there are no published threads
/// (and no active hashtag filter — when a filter is active we keep the
/// header so the user can clear an empty result).
class _ThreadsStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeThreadsProvider);
    final filter = ref.watch(threadHashtagFilterProvider);
    final s = ref.watch(stringsProvider);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (threads) {
        if (threads.isEmpty && filter == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: BananSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                overline: 'Câu chuyện',
                title: s.fromTheBakery,
                trailing: filter != null
                    ? InputChip(
                        label: Text(filter),
                        onDeleted: () => ref
                            .read(threadHashtagFilterProvider.notifier)
                            .state = null,
                      )
                    : null,
              ),
              if (threads.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: BananSpacing.lg,),
                  child: Text(
                    s.noPostsYet,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      children: [
                        for (final t in threads)
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: BananSpacing.lg,),
                            child: _ThreadCard(thread: t),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One Instagram-style post: image carousel, caption, hashtags, optional
/// "Shop this" product link and CTA button. Fires a one-shot impression
/// when first built.
class _ThreadCard extends ConsumerStatefulWidget {
  const _ThreadCard({required this.thread});
  final Thread thread;

  @override
  ConsumerState<_ThreadCard> createState() => _ThreadCardState();
}

class _ThreadCardState extends ConsumerState<_ThreadCard> {
  final _pageCtrl = PageController();
  int _page = 0;
  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tracked) return;
      _tracked = true;
      ref.read(threadsRepositoryProvider).trackView(widget.thread.id);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCta() async {
    final raw = widget.thread.ctaUrl;
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final thread = widget.thread;
    final fmt = DateFormat.MMMd();
    final published = thread.publishedAt ?? thread.createdAt;
    final gallery = thread.gallery;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: theme.colorScheme.surface,
        border:
            Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (gallery.isNotEmpty)
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageCtrl,
                    itemCount: gallery.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => Image.network(
                      gallery[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: BananColors.surfaceDim,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_rounded,
                            color: BananColors.cocoaSoft,),
                      ),
                    ),
                  ),
                  if (gallery.length > 1)
                    Positioned(
                      bottom: BananSpacing.sm,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < gallery.length; i++)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 3,),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _page
                                    ? Colors.white
                                    : Colors.white
                                        .withValues(alpha: 0.45),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(BananSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(thread.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: BananSpacing.xs),
                Text(thread.body, style: theme.textTheme.bodyMedium),
                if (thread.hashtags.isNotEmpty) ...[
                  const SizedBox(height: BananSpacing.sm),
                  Wrap(
                    spacing: BananSpacing.xs,
                    runSpacing: BananSpacing.xs,
                    children: [
                      for (final tag in thread.hashtags)
                        ActionChip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onPressed: () => ref
                              .read(threadHashtagFilterProvider.notifier)
                              .state = tag,
                        ),
                    ],
                  ),
                ],
                if (thread.productId != null) ...[
                  const SizedBox(height: BananSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/product/${thread.productId}'),
                    icon: const Icon(Icons.storefront_rounded),
                    label: Text(
                      thread.productName == null
                          ? s.shopThisProduct
                          : 'Shop: ${thread.productName}',
                    ),
                  ),
                ],
                if ((thread.ctaUrl ?? '').isNotEmpty) ...[
                  const SizedBox(height: BananSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _openCta,
                      child: Text(
                        (thread.ctaLabel ?? '').isEmpty
                            ? 'Learn more'
                            : thread.ctaLabel!,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: BananSpacing.sm),
                Row(
                  children: [
                    Text(
                      fmt.format(published.toLocal()),
                      style: theme.textTheme.labelSmall,
                    ),
                    if (thread.viewCount > 0) ...[
                      const SizedBox(width: BananSpacing.sm),
                      Icon(Icons.remove_red_eye_rounded,
                          size: 14,
                          color: theme.textTheme.labelSmall?.color,),
                      const SizedBox(width: 3),
                      Text('${thread.viewCount}',
                          style: theme.textTheme.labelSmall,),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ChowNow-style "Đặt lại / Order Again" strip. Shown only to a signed-in
/// customer who has at least one past order; collapses to nothing while
/// loading, on error, for guests, or when there's no history. Each card
/// re-adds that order's still-available items via the shared [reorderOrder]
/// helper (availability-aware).
class _OrderAgainStrip extends ConsumerWidget {
  const _OrderAgainStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentOrdersProvider);
    final orders = async.valueOrNull ?? const <Order>[];
    if (orders.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            overline: 'Nhanh gọn',
            title: '🔁 Đặt lại',
            subtitle: 'Thêm lại nhanh những món bạn đã đặt gần đây.',
          ),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: orders.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: BananSpacing.md),
              itemBuilder: (context, i) =>
                  _OrderAgainCard(order: orders[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// One compact "order again" card: a short item summary, the order date,
/// the total, and a prominent "Đặt lại" CTA.
class _OrderAgainCard extends ConsumerWidget {
  const _OrderAgainCard({required this.order});

  final Order order;

  /// "Bánh kem dâu" → "Bánh kem dâu +2 món khác" when the order has more
  /// than one line.
  String _summary() {
    if (order.items.isEmpty) return 'Đơn ${order.code}';
    final first = order.items.first.productName;
    final others = order.items.length - 1;
    return others <= 0 ? first : '$first +$others món khác';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final dateLabel = DateFormat('d MMM', 'vi_VN').format(
      order.createdAt.toLocal(),
    );

    return SizedBox(
      width: 240,
      child: Container(
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rlg,
          color: theme.colorScheme.surface,
          border:
              Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: BananSpacing.xs),
                Text(
                  dateLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: BananSpacing.xs),
            Expanded(
              child: Text(
                _summary(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: BananSpacing.xs),
            Text(
              fmt.format(order.total),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: BananSpacing.sm,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Đặt lại'),
                onPressed: () => reorderOrder(context, ref, order),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned categories — each one renders as its own horizontal product carousel
/// on the home page (driven by `pinnedCategoriesProvider`, which carries each
/// category's `products`).
class _PinnedCategories extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pinnedCategoriesProvider);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (categories) {
        final visible =
            categories.where((c) => c.products.isNotEmpty).toList();
        if (visible.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in visible) _CategoryStrip(category: c),
          ],
        );
      },
    );
  }
}

/// Top-level helper shared by every product surface (menu grid, collection
/// carousels, search results) so the quick-add UX is identical everywhere:
/// single-variant → straight to cart; multi-variant → bottom sheet picker.
Future<void> quickAddToCart({
  required BuildContext context,
  required WidgetRef ref,
  required Product product,
}) async {
  // Birthday-collection cakes are quick-addable too: tapping "+" opens the
  // cake personalization wizard inline (after a size picker when the cake
  // has multiple variants) so the customer never has to leave the grid.
  if (product.isBirthdayCake) {
    await _quickAddBirthdayCake(context: context, ref: ref, product: product);
    return;
  }
  // Macaron sets still need the full detail screen — the flavour composer
  // is an inline panel, not a bottom sheet.
  if (product.hasFlavorComposer) {
    // Fire-and-forget: nothing here cares about the popped result.
    unawaited(context.push('/product/${product.id}'));
    return;
  }
  if (product.variants.length <= 1) {
    final v = product.variants.firstOrNull;
    _confirmAddToCart(
      context: context,
      ref: ref,
      product: product,
      variantId: v?.id ?? product.id,
      variantLabel: v == null ? '' : '${v.size} · ${v.flavor}',
      unitPrice: v == null ? product.basePrice : product.priceFor(v),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _QuickAddSheet(
      product: product,
      onAdd: (variant, qty) {
        _confirmAddToCart(
          context: context,
          ref: ref,
          product: product,
          variantId: variant.id,
          variantLabel: '${variant.size} · ${variant.flavor}',
          unitPrice: product.priceFor(variant),
          quantity: qty,
        );
      },
    ),
  );
}

/// Quick-add flow for birthday-collection cakes. Resolves the size variant
/// (straight through for single-variant cakes, size picker otherwise), then
/// opens the cake personalization wizard. Dismissing either step aborts the
/// add — nothing lands in the cart unless the customer confirms.
Future<void> _quickAddBirthdayCake({
  required BuildContext context,
  required WidgetRef ref,
  required Product product,
}) async {
  var variant = product.variants.length == 1
      ? product.variants.first
      : null;
  var qty = 1;

  // Multi-size cake → ask for the size + quantity first. We capture the
  // pick via the sheet's onAdd callback (the sheet pops itself), then read
  // it back after the future resolves so there's no double-pop.
  if (product.variants.length > 1) {
    ProductVariant? picked;
    var pickedQty = 1;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _QuickAddSheet(
        product: product,
        onAdd: (v, q) {
          picked = v;
          pickedQty = q;
        },
      ),
    );
    if (picked == null) return; // dismissed without choosing a size
    variant = picked;
    qty = pickedQty;
  }

  if (!context.mounted) return;
  final perso = await showCakeWizard(context, productName: product.name);
  if (perso == null) return; // wizard dismissed → don't add

  if (!context.mounted) return;
  _confirmAddToCart(
    context: context,
    ref: ref,
    product: product,
    variantId: variant?.id ?? product.id,
    variantLabel: variant == null ? '' : '${variant.size} · ${variant.flavor}',
    unitPrice: variant == null ? product.basePrice : product.priceFor(variant),
    quantity: qty,
    personalization: perso.isEmpty ? null : perso.toMap(),
    isBirthdayCake: true,
  );
}

void _confirmAddToCart({
  required BuildContext context,
  required WidgetRef ref,
  required Product product,
  required String variantId,
  required String variantLabel,
  required double unitPrice,
  int quantity = 1,
  Map<String, dynamic>? personalization,
  bool isBirthdayCake = false,
}) {
  ref.read(cartControllerProvider.notifier).add(
        CartItem(
          productId: product.id,
          variantId: variantId,
          productName: product.name,
          variantLabel: variantLabel,
          unitPrice: unitPrice,
          quantity: quantity,
          coverImage: product.coverImage,
          personalization:
              (personalization == null || personalization.isEmpty)
                  ? null
                  : personalization,
          isBirthdayCake: isBirthdayCake,
          leadTimeHours: product.leadTimeHours,
          availableDaysOfWeek: product.availableDaysOfWeek,
        ),
      );
  // Replace any existing snackbar instead of stacking — repeated quick
  // adds otherwise queue up SnackBars that linger across navigations.
  final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      // No "Xem giỏ" action here — the persistent cart FAB on this screen
      // already offers it, so the action would be a duplicate.
      content: Text('Đã thêm ${product.name} vào giỏ.'),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Horizontal product carousel for one pinned category — driven by a
/// [Category] (title = category name, items = category.products).
class _CategoryStrip extends ConsumerWidget {
  const _CategoryStrip({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = category.products;
    final session = ref.watch(authSessionProvider).valueOrNull;
    final wishlistAsync = ref.watch(wishlistIdsProvider);
    final showStock = ref
            .watch(displayConfigProvider)
            .valueOrNull
            ?.showStockToCustomers ??
        false;
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            overline: 'Danh mục',
            title: category.name,
          ),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: BananSpacing.md),
              itemBuilder: (context, i) {
                final p = products[i];
                return SizedBox(
                  width: 180,
                  child: ProductCard(
                    name: p.name,
                    imageUrl: p.coverImage,
                    minPrice: p.minPrice,
                    hasPriceRange: p.hasPriceRange,
                    seasonal: p.isSeasonal,
                    tags: p.tags,
                    averageRating: p.averageRating,
                    reviewCount: p.reviewCount,
                    stockRemaining: showStock ? p.totalLimitedStock : null,
                    soldOut: showStock && p.isSoldOut,
                    isWishlisted: isWishlisted(wishlistAsync, p.id),
                    onToggleWishlist: session == null
                        ? null
                        : () => ref
                            .read(wishlistIdsProvider.notifier)
                            .toggle(p.id),
                    onTap: () => context.push('/product/${p.id}'),
                    onQuickAdd: (showStock && p.isSoldOut)
                        ? null
                        : () => quickAddToCart(
                              context: context,
                              ref: ref,
                              product: p,
                            ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact variant + quantity picker for the menu's quick-add flow. Lives
/// in a bottom sheet so the customer never leaves the grid — the full
/// product detail screen is still one tap away on the card body.
class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet({required this.product, required this.onAdd});

  final Product product;
  final void Function(ProductVariant variant, int qty) onAdd;

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  late ProductVariant _selected;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    // Default to the cheapest variant — most customers add the base
    // option and upgrade rarely. Picking the cheapest also matches the
    // "From X" price shown on the menu card.
    final sorted = [...widget.product.variants]
      ..sort((a, b) => a.priceDelta.compareTo(b.priceDelta));
    _selected = sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final unitPrice = widget.product.priceFor(_selected);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        BananSpacing.lg,
        0,
        BananSpacing.lg,
        bottom + BananSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.product.coverImage != null)
                ClipRRect(
                  borderRadius: BananRadii.rmd,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Image.network(
                      widget.product.coverImage!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (widget.product.coverImage != null)
                const SizedBox(width: BananSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.product.name, style: theme.textTheme.titleMedium),
                    Text(
                      fmt.format(unitPrice),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.lg),
          Text('Chọn phiên bản', style: theme.textTheme.titleSmall),
          const SizedBox(height: BananSpacing.sm),
          Wrap(
            spacing: BananSpacing.sm,
            runSpacing: BananSpacing.sm,
            children: [
              for (final v in widget.product.variants)
                ChoiceChip(
                  label: Text(
                    v.priceDelta == 0
                        ? '${v.size} · ${v.flavor}'
                        : '${v.size} · ${v.flavor} (+${fmt.format(v.priceDelta)})',
                  ),
                  selected: v.id == _selected.id,
                  onSelected: v.isAvailable
                      ? (_) => setState(() => _selected = v)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: BananSpacing.lg),
          Row(
            children: [
              Text('Số lượng', style: theme.textTheme.titleSmall),
              const Spacer(),
              IconButton.outlined(
                icon: const Icon(Icons.remove),
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$_qty',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton.outlined(
                icon: const Icon(Icons.add),
                onPressed: _qty < 99 ? () => setState(() => _qty++) : null,
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.lg),
          FilledButton.icon(
            onPressed: () {
              widget.onAdd(_selected, _qty);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.shopping_basket_outlined),
            label: Text(
              'Thêm vào giỏ · ${fmt.format(unitPrice * _qty)}',
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              GoRouter.of(context).push('/product/${widget.product.id}');
            },
            child: const Text('Xem chi tiết sản phẩm'),
          ),
        ],
      ),
    );
  }
}

/// Newsletter signup at the bottom of the menu — tiny opt-in form with
/// inline confirm message. Friction-low (just email) to maximise capture
/// rate; double opt-in mail is sent server-side so the address is
/// quality-checked before campaigns.
class _NewsletterFooter extends ConsumerStatefulWidget {
  const _NewsletterFooter();

  @override
  ConsumerState<_NewsletterFooter> createState() =>
      _NewsletterFooterState();
}

class _NewsletterFooterState extends ConsumerState<_NewsletterFooter> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _ok = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@') || email.length < 5) {
      setState(() {
        _ok = false;
        _msg = 'Vui lòng nhập email hợp lệ.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    final res = await ref.read(newsletterApiProvider).subscribe(
          email: email,
          source: 'footer',
        );
    if (!mounted) return;
    res.when(
      success: (r) {
        setState(() {
          _busy = false;
          _ok = true;
          _msg = r.alreadyConfirmed
              ? 'Bạn đã đăng ký rồi — cảm ơn!'
              : 'Đã gửi email xác nhận, mời kiểm tra hộp thư.';
          if (!r.alreadyConfirmed) _email.clear();
        });
      },
      failure: (f) {
        setState(() {
          _busy = false;
          _ok = false;
          _msg = f.message ?? 'Có lỗi xảy ra — vui lòng thử lại.';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(
        top: BananSpacing.xl,
        bottom: BananSpacing.xxxl,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.xl,
        vertical: BananSpacing.xl,
      ),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: BananColors.primary.withValues(alpha: 0.06),
        border: Border.all(
          color: BananColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nhận khuyến mãi từ Banan',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BananSpacing.xs),
              Text(
                'Đăng ký email để nhận thông tin bánh mới + ưu đãi mùa lễ. '
                'Tối đa 2 email / tháng — không spam.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BananSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'your@email.com',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _busy ? null : _submit(),
                    ),
                  ),
                  const SizedBox(width: BananSpacing.sm),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Đăng ký'),
                  ),
                ],
              ),
              if (_msg != null) ...[
                const SizedBox(height: BananSpacing.sm),
                Text(
                  _msg!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _ok
                        ? BananColors.success
                        : theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

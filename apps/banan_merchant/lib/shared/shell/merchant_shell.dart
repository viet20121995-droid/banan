import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'change_password_dialog.dart';

/// Persistent navigation shell shared by every merchant screen.
///
/// Lays out a left sidebar (desktop ≥ md) + slim app bar; on mobile the
/// sidebar collapses into a Drawer opened via a hamburger icon. Replaces
/// the 14-icon AppBar that every page used to redefine on its own.
///
/// Usage:
/// ```dart
/// MerchantShell(
///   title: 'Đơn hàng',
///   onRefresh: controller.refresh,    // optional
///   action: FilledButton.icon(...),   // optional per-page primary action
///   body: _OrderList(),
/// )
/// ```
class MerchantShell extends ConsumerWidget {
  const MerchantShell({
    required this.title,
    required this.body,
    this.onRefresh,
    this.action,
    this.floatingActionButton,
    super.key,
  });

  /// Shown in the app bar — page-level identifier.
  final String title;
  final Widget body;

  /// Optional refresh callback. When non-null a refresh icon button shows
  /// in the app bar; many screens use this in lieu of pull-to-refresh.
  final Future<void> Function()? onRefresh;

  /// Optional per-page primary action (button, status chip, …) shown
  /// to the right of the title in the app bar. Use for things like the
  /// orders "Send to kitchen" or product "Save" buttons.
  final Widget? action;

  /// Per-page FAB — forwarded to Scaffold so screens keep their existing
  /// "View cart" / "New product" / etc. floating buttons.
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final bp = Breakpoint.fromWidth(width);
    // Persistent sidebar only when there's room (≥ 905px). Below that, the
    // sidebar lives behind a hamburger in the Drawer slot.
    final showRail = bp.isAtLeastMd;

    return Scaffold(
      appBar: AppBar(
        leading: showRail
            ? null
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Menu',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        title: Text(title),
        actions: [
          if (action != null) ...[
            action!,
            const SizedBox(width: BananSpacing.sm),
          ],
          if (onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới',
              onPressed: () => onRefresh!.call(),
            ),
          const _AccountMenu(),
          const SizedBox(width: BananSpacing.sm),
        ],
      ),
      drawer: showRail ? null : const Drawer(child: _SidebarNav()),
      floatingActionButton: floatingActionButton,
      body: showRail
          ? Row(
              children: [
                const SizedBox(width: 240, child: _SidebarNav()),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }
}

/// Account chip in the app bar — shows initial + opens a popup menu with
/// the user's name, role, and a sign-out action. Keeps the "who am I /
/// log out" affordance present on every page without burning a slot.
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final user = session?.user;
    final theme = Theme.of(context);
    final initial = (user?.fullName.trim().isNotEmpty ?? false)
        ? user!.fullName.trim()[0].toUpperCase()
        : '?';

    return PopupMenuButton<String>(
      tooltip: 'Tài khoản của bạn',
      offset: const Offset(0, 44),
      onSelected: (v) {
        if (v == 'logout') {
          ref.read(authControllerProvider.notifier).logout();
        } else if (v == 'password') {
          showChangePasswordDialog(context, ref);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user?.fullName ?? '—',
                style: theme.textTheme.titleSmall,
              ),
              if (user != null)
                Text(
                  '${user.email}  ·  ${_roleLabel(user.role)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'password',
          child: Row(
            children: [
              Icon(Icons.password_outlined, size: 18),
              SizedBox(width: 8),
              Text('Đổi mật khẩu'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 8),
              Text('Đăng xuất'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: BananColors.gold,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel(Role r) => switch (r) {
        Role.admin => 'Admin',
        Role.merchantOwner => 'Chủ cửa hàng',
        Role.merchantStaff => 'Nhân viên',
        Role.kitchenManager => 'Quản lý bếp',
        Role.kitchenStaff => 'Nhân viên bếp',
        Role.customer => 'Khách hàng',
      };
}

// ─── Sidebar ────────────────────────────────────────────────────────────

class _SidebarNav extends ConsumerStatefulWidget {
  const _SidebarNav();

  @override
  ConsumerState<_SidebarNav> createState() => _SidebarNavState();
}

class _SidebarNavState extends ConsumerState<_SidebarNav> {
  /// Labels of the currently-expanded sections. Initialised once (per shell
  /// mount) to just the section that owns the current route, so the sidebar
  /// opens compact — one open group, the rest collapsed to a single row.
  final Set<String> _expanded = {};
  bool _initialised = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = ref.watch(authSessionProvider).valueOrNull?.user.role;
    final isAdmin = role?.isAdmin ?? false;
    final isOwner = role == Role.merchantOwner;
    final currentPath = GoRouterState.of(context).matchedLocation;

    // Sidebar layout, grouped into collapsible sections. Several entries are
    // intentionally hidden for the ADMIN role because their backend endpoints
    // require a `storeId` and the admin user doesn't belong to a single store
    // (they manage the chain) — showing them would land the admin on a Prisma
    // error every time.
    final groups = <_NavGroup>[
      const _NavGroup(
        label: 'VẬN HÀNH',
        icon: Icons.point_of_sale_outlined,
        items: [
          _NavItem(
            label: 'Đơn hàng',
            icon: Icons.receipt_long_outlined,
            iconSelected: Icons.receipt_long,
            route: '/',
          ),
          _NavItem(
            label: 'Hoàn tiền',
            icon: Icons.assignment_return_outlined,
            iconSelected: Icons.assignment_return,
            route: '/refunds',
          ),
        ],
      ),
      _NavGroup(
        label: 'THỰC ĐƠN',
        icon: Icons.restaurant_menu_outlined,
        items: [
          // Catalog products live on a shared "catalog store" — works for
          // both merchant and admin.
          const _NavItem(
            label: 'Sản phẩm',
            icon: Icons.menu_book_outlined,
            iconSelected: Icons.menu_book,
            route: '/menu',
          ),
          // Catalog content (categories, combos, bulk product tools) is now
          // chain-wide and ADMIN-managed — shown to admin, hidden from merchant
          // branches. Products above stay visible to merchants (read-only).
          if (isAdmin)
            const _NavItem(
              label: 'Danh mục',
              icon: Icons.category_outlined,
              iconSelected: Icons.category,
              route: '/categories',
            ),
          // "Bộ sưu tập" (Collections) nav item retired — superseded by
          // pinned categories on the customer home. Routes/screens left
          // dormant so existing deep links still resolve.
          if (isAdmin)
            const _NavItem(
              label: 'Combo',
              icon: Icons.style_outlined,
              iconSelected: Icons.style,
              route: '/bundles',
            ),
          if (isAdmin)
            const _NavItem(
              label: 'Công cụ hàng loạt',
              icon: Icons.dynamic_feed_outlined,
              iconSelected: Icons.dynamic_feed,
              route: '/tools/bulk',
            ),
        ],
      ),
      _NavGroup(
        label: 'MARKETING',
        icon: Icons.sell_outlined,
        items: [
          // Promotions / campaigns — admin-managed chain-wide programs.
          // Backend gates this on the ADMIN role; owners see it too.
          if (isAdmin || isOwner)
            const _NavItem(
              label: 'Khuyến mãi',
              icon: Icons.sell_outlined,
              iconSelected: Icons.sell,
              route: '/campaigns',
            ),
          // Per-store coupons — hidden for admin.
          if (!isAdmin)
            const _NavItem(
              label: 'Mã giảm giá',
              icon: Icons.confirmation_number_outlined,
              iconSelected: Icons.confirmation_number,
              route: '/coupons',
            ),
          // Loyalty / rewards programs are chain-wide admin config; the
          // backend gates writes on owner/admin, so staff would hit a 403.
          if (isAdmin || isOwner)
            const _NavItem(
              label: 'Chương trình ưu đãi',
              icon: Icons.redeem_outlined,
              iconSelected: Icons.redeem,
              route: '/marketing',
            ),
          const _NavItem(
            label: 'Popup quảng cáo',
            icon: Icons.ad_units_outlined,
            iconSelected: Icons.ad_units,
            route: '/admin/promo-popup',
          ),
          const _NavItem(
            label: 'Banner',
            icon: Icons.photo_library_outlined,
            iconSelected: Icons.photo_library,
            route: '/banners',
          ),
          // Posts (Bài đăng) are chain-wide editorial content → ADMIN only.
          if (isAdmin)
            const _NavItem(
              label: 'Bài đăng',
              icon: Icons.forum_outlined,
              iconSelected: Icons.forum,
              route: '/threads',
            ),
        ],
      ),
      _NavGroup(
        label: 'KHÁCH HÀNG',
        icon: Icons.groups_outlined,
        items: [
          if (!isAdmin)
            const _NavItem(
              label: 'Danh sách',
              icon: Icons.people_outline,
              iconSelected: Icons.people,
              route: '/customers',
            ),
          const _NavItem(
            label: 'Đánh giá',
            icon: Icons.star_outline,
            iconSelected: Icons.star,
            route: '/reviews',
          ),
          // Newsletter + system broadcast are chain-wide marketing → admin-only
          // (the backend enforces ADMIN on these routes; hide them for owners/
          // staff so they don't tap into a 403).
          if (isAdmin)
            const _NavItem(
              label: 'Newsletter',
              icon: Icons.mail_outline,
              iconSelected: Icons.mail,
              route: '/newsletter',
            ),
          if (isAdmin)
            const _NavItem(
              label: 'Thông báo',
              icon: Icons.notifications_active_outlined,
              iconSelected: Icons.notifications_active,
              route: '/broadcast',
            ),
        ],
      ),
      const _NavGroup(
        label: 'PHÂN TÍCH',
        icon: Icons.insights_outlined,
        items: [
          _NavItem(
            label: 'Dashboard',
            icon: Icons.bar_chart_outlined,
            iconSelected: Icons.bar_chart,
            route: '/dashboard',
          ),
          _NavItem(
            label: 'Báo cáo',
            icon: Icons.assessment_outlined,
            iconSelected: Icons.assessment,
            route: '/reports',
          ),
        ],
      ),
      _NavGroup(
        label: 'CÀI ĐẶT',
        icon: Icons.settings_outlined,
        items: [
          // Per-store opening hours / pause toggle — hidden for admin.
          if (!isAdmin)
            const _NavItem(
              label: 'Cửa hàng',
              icon: Icons.storefront_outlined,
              iconSelected: Icons.storefront,
              route: '/settings',
            ),
          if (isAdmin)
            const _NavItem(
              label: 'Phí giao hàng',
              icon: Icons.local_shipping_outlined,
              iconSelected: Icons.local_shipping,
              route: '/admin/delivery-config',
            ),
          // Chain-wide display prefs + editorial page content are owner/admin
          // config — staff hit a 403 on the underlying endpoints.
          if (isAdmin || isOwner)
            const _NavItem(
              label: 'Hiển thị (tồn kho…)',
              icon: Icons.visibility_outlined,
              iconSelected: Icons.visibility,
              route: '/admin/display',
            ),
          if (isAdmin || isOwner)
            const _NavItem(
              label: 'Nội dung trang',
              icon: Icons.article_outlined,
              iconSelected: Icons.article,
              route: '/settings/content',
            ),
          if (isAdmin)
            const _NavItem(
              label: 'Tài khoản',
              icon: Icons.admin_panel_settings_outlined,
              iconSelected: Icons.admin_panel_settings,
              route: '/admin/accounts',
            ),
        ],
      ),
    ];

    // Drop empty groups (admin hides several store-scoped items).
    final visible = groups.where((g) => g.items.isNotEmpty).toList();

    bool groupActive(_NavGroup g) =>
        g.items.any((it) => _routeMatches(currentPath, it.route));

    // One-time init: open only the section that owns the current route so the
    // sidebar starts compact. Afterwards the user's expand/collapse wins.
    if (!_initialised) {
      for (final g in visible) {
        if (groupActive(g)) _expanded.add(g.label);
      }
      if (_expanded.isEmpty && visible.isNotEmpty) {
        _expanded.add(visible.first.label);
      }
      _initialised = true;
    }

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand strip — quick visual anchor at the top of the sidebar.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BananSpacing.lg,
                BananSpacing.lg,
                BananSpacing.lg,
                BananSpacing.md,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: BananColors.primary,
                    child: Text(
                      'B',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: BananSpacing.sm),
                  Expanded(
                    child: Text(
                      'Banan',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: BananSpacing.sm,
                ),
                children: [
                  for (final group in visible) ...[
                    _GroupHeader(
                      label: group.label,
                      icon: group.icon,
                      expanded: _expanded.contains(group.label),
                      active: groupActive(group),
                      onTap: () => setState(() {
                        if (!_expanded.remove(group.label)) {
                          _expanded.add(group.label);
                        }
                      }),
                    ),
                    if (_expanded.contains(group.label))
                      for (final item in group.items)
                        Padding(
                          padding: const EdgeInsets.only(left: BananSpacing.md),
                          child: _NavTile(
                            item: item,
                            selected: _routeMatches(currentPath, item.route),
                            onTap: () {
                              // Close the drawer on mobile before navigating
                              // so the user lands on the new screen, not back
                              // on the still-open drawer.
                              final scaffold = Scaffold.maybeOf(context);
                              if (scaffold?.isDrawerOpen ?? false) {
                                Navigator.of(context).pop();
                              }
                              context.go(item.route);
                            },
                          ),
                        ),
                  ],
                ],
              ),
            ),
            // Always-visible user info + explicit logout at the bottom.
            // The top-right avatar popup is still there for fast access,
            // but having "Đăng xuất" in plain text removes any guesswork
            // about how to sign out — most business-app users expect it
            // at the bottom of the sidebar.
            const Divider(height: 1),
            const _SidebarUserFooter(),
          ],
        ),
      ),
    );
  }

  /// Returns true when [current] is on the section owned by [target].
  /// `/orders/123` lives under the `/` orders queue; `/menu/abc` under
  /// `/menu`; deeper paths still light up the parent section so the
  /// merchant always knows what they were navigating from.
  bool _routeMatches(String current, String target) {
    if (target == '/') {
      return current == '/' || current.startsWith('/orders');
    }
    return current == target || current.startsWith('$target/');
  }
}

/// Tappable section header for the collapsible sidebar. Shows the section
/// icon + label and a chevron that flips with the expanded state. When the
/// section owns the current route it tints to the primary colour so the
/// merchant can still see "where they are" even while it's collapsed.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.icon,
    required this.expanded,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool expanded;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.72);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.sm,
        vertical: 1,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            BananSpacing.md,
            BananSpacing.sm,
            BananSpacing.sm,
            BananSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: BananSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.sm,
        vertical: 1,
      ),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BananSpacing.md,
              vertical: BananSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? item.iconSelected : item.icon,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: BananSpacing.md),
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavGroup {
  const _NavGroup({
    required this.label,
    required this.icon,
    required this.items,
  });
  final String label;
  final IconData icon;
  final List<_NavItem> items;
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.iconSelected,
    required this.route,
  });
  final String label;
  final IconData icon;
  final IconData iconSelected;
  final String route;
}

/// Sticky footer of the sidebar — avatar + name + role on the left,
/// explicit "Đăng xuất" button on the right. Tap the row to open the
/// admin Tài khoản page (admin only) so this also doubles as the entry
/// point for "manage other accounts" without burning a sidebar slot.
class _SidebarUserFooter extends ConsumerWidget {
  const _SidebarUserFooter();

  String _roleLabel(Role r) => switch (r) {
        Role.admin => 'Admin',
        Role.merchantOwner => 'Chủ cửa hàng',
        Role.merchantStaff => 'Nhân viên',
        Role.kitchenManager => 'Quản lý bếp',
        Role.kitchenStaff => 'Nhân viên bếp',
        Role.customer => 'Khách hàng',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull?.user;
    final isAdmin = user?.role == Role.admin;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final initial = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()[0].toUpperCase()
        : '?';
    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BananSpacing.md,
          BananSpacing.sm,
          BananSpacing.sm,
          BananSpacing.sm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: BananColors.gold,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: BananSpacing.sm),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: isAdmin
                    ? () => context.go('/admin/accounts')
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _roleLabel(user.role),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Đăng xuất',
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// App chrome for the internal ops app: role-filtered sidebar (persistent
/// ≥ md, drawer below), a quiet header with screen title + optional context
/// line + account/logout. No marketing, no decoration.
class InternalShell extends ConsumerWidget {
  const InternalShell({
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;

  static const _adminItems = [
    _NavSpec('/qc', Icons.fact_check_outlined, 'QC'),
    _NavSpec('/ms', Icons.visibility_outlined, 'Mystery Shopper'),
    _NavSpec('/training', Icons.school_outlined, 'Training'),
    _NavSpec('/schedule', Icons.calendar_month_outlined, 'Lịch làm'),
    // Any /survey/* admin page highlights this item; the public guest form
    // lives on the customer domain, not in this app.
    _NavSpec('/survey/reports', Icons.reviews_outlined, 'Khảo sát', selectedPrefix: '/survey/'),
  ];
  static const _traineeItems = [
    _NavSpec('/training', Icons.school_outlined, 'Đào tạo của tôi'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bp = Breakpoint.fromWidth(MediaQuery.sizeOf(context).width);
    final wide = bp.isAtLeastMd;
    final role = ref.watch(authSessionProvider).valueOrNull?.user.role;
    final nav = _SidebarNav(items: role == Role.trainee ? _traineeItems : _adminItems);

    return Scaffold(
      appBar: AppBar(
        leading: wide
            ? IconButton(
                tooltip: 'Trang chủ',
                icon: const Icon(Icons.home_outlined),
                onPressed: () => context.go('/'),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null)
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [...actions, const _AccountMenu(), const SizedBox(width: BananSpacing.sm)],
      ),
      drawer: wide ? null : Drawer(child: SafeArea(child: nav)),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              SizedBox(
                width: 220,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: nav,
                ),
              ),
            if (wide) const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.path, this.icon, this.label, {this.selectedPrefix});
  final String path;
  final IconData icon;
  final String label;

  /// Overrides the default "path or path/*" selected match — for items whose
  /// section spans sibling routes (e.g. /survey/reports vs /survey/cases).
  final String? selectedPrefix;
}

class _SidebarNav extends StatelessWidget {
  const _SidebarNav({required this.items});
  final List<_NavSpec> items;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: BananSpacing.md),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BananSpacing.lg,
            BananSpacing.sm,
            BananSpacing.lg,
            BananSpacing.lg,
          ),
          child: InkWell(
            onTap: () => context.go('/'),
            child: Text(
              'Banan · Nội bộ',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: BananColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        for (final item in items)
          ListTile(
            leading: Icon(item.icon, size: 20),
            title: Text(item.label),
            selected: item.selectedPrefix != null
                ? location.startsWith(item.selectedPrefix!)
                : location == item.path || location.startsWith('${item.path}/'),
            onTap: () {
              // Close the drawer first on mobile.
              if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                Navigator.of(context).pop();
              }
              context.go(item.path);
            },
          ),
      ],
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).valueOrNull?.user;
    return PopupMenuButton<String>(
      tooltip: 'Tài khoản',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (value) async {
        if (value == 'logout') {
          await ref.read(authControllerProvider.notifier).logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(user?.email ?? '—', overflow: TextOverflow.ellipsis),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout, size: 20),
            title: Text('Đăng xuất'),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Desktop workspace for the central-kitchen app.
///
/// Operational screens keep their own app bars. This shell only provides
/// persistent navigation and a quieter, higher-contrast work surface.
class KitchenWorkspaceShell extends StatelessWidget {
  const KitchenWorkspaceShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final base = Theme.of(context);
    final operationalTheme = base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF4F5F2),
      colorScheme: base.colorScheme.copyWith(
        surface: Colors.white,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF7F8F5),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );

    if (width < 1080) {
      return Theme(data: operationalTheme, child: child);
    }

    return Theme(
      data: operationalTheme,
      child: Scaffold(
        body: Row(
          children: [
            _WorkspaceNavigation(location: location),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceNavigation extends StatelessWidget {
  const _WorkspaceNavigation({required this.location});

  final String location;

  static const _groups = <_NavGroup>[
    _NavGroup(
      label: 'VẬN HÀNH',
      items: [
        _NavItem('Đơn bếp', '/', Icons.view_kanban_outlined),
        _NavItem(
          'Đặt hàng nội bộ',
          '/transfer-summary',
          Icons.compare_arrows_outlined,
        ),
        _NavItem(
          'Tổng quan sản xuất',
          '/production',
          Icons.space_dashboard_outlined,
          exact: true,
        ),
      ],
    ),
    _NavGroup(
      label: 'SẢN XUẤT',
      items: [
        _NavItem(
          'Xưởng sản xuất',
          '/production/shop-floor',
          Icons.precision_manufacturing_outlined,
        ),
        _NavItem(
          'Lịch sản xuất',
          '/production/schedule',
          Icons.calendar_month_outlined,
        ),
        _NavItem(
          'Lệnh sản xuất',
          '/production/orders',
          Icons.assignment_outlined,
        ),
      ],
    ),
    _NavGroup(
      label: 'KHO & MUA HÀNG',
      items: [
        _NavItem(
          'Tồn kho & lô',
          '/production/stock',
          Icons.inventory_2_outlined,
        ),
        _NavItem(
          'Cần mua / cần làm',
          '/production/replenishment',
          Icons.playlist_add_check_outlined,
        ),
        _NavItem(
          'Đơn mua hàng',
          '/production/purchase-orders',
          Icons.shopping_cart_outlined,
        ),
      ],
    ),
    _NavGroup(
      label: 'CHẤT LƯỢNG',
      items: [
        _NavItem(
          'Cảnh báo QC',
          '/production/alerts',
          Icons.fact_check_outlined,
        ),
        _NavItem(
          'Báo cáo',
          '/production/reports',
          Icons.analytics_outlined,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF17241B),
      child: SafeArea(
        child: SizedBox(
          width: 236,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BANAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'BẾP TRUNG TÂM',
                      style: TextStyle(
                        color: Color(0xFFA9B7AC),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF324238), height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
                  children: [
                    for (final group in _groups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                        child: Text(
                          group.label,
                          style: const TextStyle(
                            color: Color(0xFF829087),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      for (final item in group.items)
                        _NavigationTile(
                          item: item,
                          selected: item.matches(location),
                        ),
                    ],
                  ],
                ),
              ),
              const Divider(color: Color(0xFF324238), height: 1),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: _FooterButton(
                        icon: Icons.notifications_none,
                        tooltip: 'Thông báo',
                        onPressed: () => context.go('/notifications'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FooterButton(
                        icon: Icons.manage_accounts_outlined,
                        tooltip: 'Tài khoản',
                        onPressed: () => context.go('/change-password'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({required this.item, required this.selected});

  final _NavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : const Color(0xFFC7D0C9);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? const Color(0xFF2D6D3E) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.go(item.path),
          child: SizedBox(
            height: 42,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(item.icon, color: foreground, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Colors.white,
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

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: const Color(0xFFC7D0C9),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF243229),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

class _NavGroup {
  const _NavGroup({required this.label, required this.items});

  final String label;
  final List<_NavItem> items;
}

class _NavItem {
  const _NavItem(this.label, this.path, this.icon, {this.exact = false});

  final String label;
  final String path;
  final IconData icon;
  final bool exact;

  bool matches(String location) {
    if (path == '/') return location == '/';
    if (exact) return location == path;
    return location == path || location.startsWith('$path/');
  }
}

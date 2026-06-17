import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

/// Query key for the dashboard summary — time range plus an optional branch
/// scope (admin-only; null = whole chain / merchant's own store).
typedef _SummaryQuery = ({String range, String? storeId});

final _summaryProvider = FutureProvider.autoDispose
    .family<MerchantSummary, _SummaryQuery>((ref, query) async {
  final res = await ref
      .watch(analyticsApiProvider)
      .merchantSummary(range: query.range, storeId: query.storeId);
  return res.when(
    success: (s) => s,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

/// The full chain of branches (admin scope) so every store shows in the
/// branch filter. Returns [] on failure (e.g. a single-store merchant gets
/// 403 from the admin endpoint — their filter is hidden anyway).
final _storesProvider =
    FutureProvider.autoDispose<List<({String id, String name})>>((ref) async {
  final res = await ref.watch(adminRepositoryProvider).stores();
  return res.when(
    success: (list) => [for (final o in list) (id: o.id, name: o.name)],
    failure: (_) => const <({String id, String name})>[],
  );
});

class MerchantDashboardScreen extends ConsumerStatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  ConsumerState<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState
    extends ConsumerState<MerchantDashboardScreen> {
  String _range = '7d';
  String? _storeId;

  @override
  Widget build(BuildContext context) {
    final query = (range: _range, storeId: _storeId);
    final summaryAsync = ref.watch(_summaryProvider(query));
    final isAdmin = ref
            .watch(authSessionProvider)
            .valueOrNull
            ?.user
            .role
            .isAdmin ??
        false;
    return MerchantShell(
      title: 'Bảng điều khiển',
      onRefresh: () async => ref.invalidate(_summaryProvider(query)),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_summaryProvider(query)),
        ),
        data: (s) => _Body(
          summary: s,
          range: _range,
          onRange: (r) => setState(() => _range = r),
          isAdmin: isAdmin,
          selectedStoreId: _storeId,
          onStore: (id) => setState(() => _storeId = id),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.summary,
    required this.range,
    required this.onRange,
    required this.isAdmin,
    required this.selectedStoreId,
    required this.onStore,
  });

  final MerchantSummary summary;
  final String range;
  final ValueChanged<String> onRange;
  final bool isAdmin;
  final String? selectedStoreId;
  final ValueChanged<String?> onStore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final t = summary.totals;
    final revenue = (t['revenue'] as num?)?.toDouble() ?? 0;
    final orders = (t['orders'] as num?)?.toInt() ?? 0;
    final completed = (t['completed'] as num?)?.toInt() ?? 0;
    final refundRate = (t['refundRate'] as num?)?.toDouble() ?? 0;
    final aov = (t['avgOrderValue'] as num?)?.toDouble() ?? 0;

    final byStore = summary.byStore;
    final byPayment = summary.byPayment;
    final fulfillment = summary.byFulfillment;
    // Only worth a per-branch breakdown for the whole-chain view (≥2 stores).
    final showByStore = selectedStoreId == null && byStore.length >= 2;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: BananSpacing.md),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: BananSpacing.lg),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '24h', label: Text('24 giờ')),
              ButtonSegment(value: '7d', label: Text('7 ngày')),
              ButtonSegment(value: '30d', label: Text('30 ngày')),
            ],
            selected: {range},
            onSelectionChanged: (s) => onRange(s.first),
          ),
        ),
        // Branch filter — admin only. Merchants are server-scoped to their
        // own store so the row would be redundant for them.
        if (isAdmin)
          _BranchFilter(
            selected: selectedStoreId,
            onSelect: onStore,
          ),
        BreakpointBuilder(
          builder: (context, bp) {
            final cols = bp.isAtLeastLg ? 4 : (bp.isAtLeastMd ? 2 : 1);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: BananSpacing.lg,
              mainAxisSpacing: BananSpacing.lg,
              childAspectRatio: 1.7,
              children: [
                StatCard(
                  label: 'Doanh thu',
                  value: fmt.format(revenue),
                  icon: Icons.payments_outlined,
                  intent: StatIntent.success,
                  hint: '$completed đơn hoàn thành',
                ),
                StatCard(
                  label: 'Đơn hàng',
                  value: '$orders',
                  icon: Icons.receipt_long_outlined,
                ),
                StatCard(
                  label: 'Tỉ lệ hoàn tiền',
                  value: '${(refundRate * 100).toStringAsFixed(1)}%',
                  icon: Icons.refresh,
                  intent: refundRate > 0.1
                      ? StatIntent.danger
                      : StatIntent.neutral,
                ),
                StatCard(
                  label: 'Giá trị đơn TB',
                  value: fmt.format(aov),
                  icon: Icons.trending_up,
                ),
                StatCard(
                  label: 'Giảm giá đã dùng',
                  value: fmt.format(summary.discountsGiven),
                  icon: Icons.local_offer_outlined,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: BananSpacing.xl),
        _Section(
          title: 'Doanh thu',
          child: SizedBox(
            height: 220,
            child: _RevenueChart(daily: summary.daily, fmt: fmt),
          ),
        ),
        if (showByStore) ...[
          const SizedBox(height: BananSpacing.xl),
          _Section(
            title: 'Doanh thu theo chi nhánh',
            child: _ByStoreList(items: byStore, fmt: fmt),
          ),
        ],
        if (fulfillment.pickup.orders > 0 ||
            fulfillment.delivery.orders > 0) ...[
          const SizedBox(height: BananSpacing.xl),
          _Section(
            title: 'Theo hình thức',
            child: _FulfillmentBreakdown(split: fulfillment, fmt: fmt),
          ),
        ],
        if (byPayment.isNotEmpty) ...[
          const SizedBox(height: BananSpacing.xl),
          _Section(
            title: 'Theo phương thức thanh toán',
            child: _PaymentBreakdown(items: byPayment),
          ),
        ],
        const SizedBox(height: BananSpacing.xl),
        _Section(
          title: 'Bán chạy nhất',
          child: _BestSellersList(items: summary.bestSellers, fmt: fmt),
        ),
        const SizedBox(height: BananSpacing.xl),
        _Section(
          title: 'Khung giờ cao điểm',
          child: SizedBox(
            height: 180,
            child: _PeakHoursChart(hours: summary.peakHours),
          ),
        ),
        const SizedBox(height: BananSpacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.push('/reports'),
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Xuất Excel & báo cáo chi tiết'),
          ),
        ),
        const SizedBox(height: BananSpacing.huge),
      ],
    );
  }
}

/// Admin-only branch scope selector. Pulls the full chain from
/// [_storesProvider]; renders nothing for a single-store account so the
/// chip row never appears for non-chain merchants.
class _BranchFilter extends ConsumerWidget {
  const _BranchFilter({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(_storesProvider).valueOrNull ?? const [];
    if (stores.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.lg),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: BananSpacing.sm),
              child: ChoiceChip(
                avatar: const Icon(Icons.storefront_outlined, size: 16),
                label: const Text('Tất cả chi nhánh'),
                selected: selected == null,
                onSelected: (_) => onSelect(null),
              ),
            ),
            for (final s in stores)
              Padding(
                padding: const EdgeInsets.only(right: BananSpacing.sm),
                child: ChoiceChip(
                  label: Text(
                    s.name.replaceFirst(RegExp(r'^Banan\s*[–-]\s*'), ''),
                  ),
                  selected: selected == s.id,
                  onSelected: (_) => onSelect(s.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal proportional-bar list of completed revenue per branch. Data
/// arrives sorted desc by revenue; bars are scaled against the top branch.
class _ByStoreList extends StatelessWidget {
  const _ByStoreList({required this.items, required this.fmt});
  final List<Map<String, dynamic>> items;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxRevenue = items.fold<double>(0, (m, e) {
      final v = (e['revenue'] as num?)?.toDouble() ?? 0;
      return v > m ? v : m;
    });
    return Column(
      children: [
        for (final e in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BananSpacing.xs),
            child: _ByStoreRow(
              name: ((e['storeName'] as String?) ?? '—')
                  .replaceFirst(RegExp(r'^Banan\s*[–-]\s*'), ''),
              revenue: (e['revenue'] as num?)?.toDouble() ?? 0,
              orders: (e['orders'] as num?)?.toInt() ?? 0,
              fraction: maxRevenue == 0
                  ? 0
                  : ((e['revenue'] as num?)?.toDouble() ?? 0) / maxRevenue,
              fmt: fmt,
              color: theme.colorScheme.primary,
            ),
          ),
      ],
    );
  }
}

class _ByStoreRow extends StatelessWidget {
  const _ByStoreRow({
    required this.name,
    required this.revenue,
    required this.orders,
    required this.fraction,
    required this.fmt,
    required this.color,
  });

  final String name;
  final double revenue;
  final int orders;
  final double fraction;
  final NumberFormat fmt;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: BananSpacing.sm),
            Text(
              '${fmt.format(revenue)} · $orders đơn',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

/// Pickup vs delivery split: revenue, order count, and % share of orders.
class _FulfillmentBreakdown extends StatelessWidget {
  const _FulfillmentBreakdown({required this.split, required this.fmt});
  final MerchantFulfillmentSplit split;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final totalOrders = split.pickup.orders + split.delivery.orders;
    return Column(
      children: [
        _BreakdownRow(
          icon: Icons.storefront_outlined,
          label: 'Lấy tại quầy',
          trailing: '${fmt.format(split.pickup.revenue)} · '
              '${split.pickup.orders} đơn',
          fraction: totalOrders == 0 ? 0 : split.pickup.orders / totalOrders,
        ),
        const SizedBox(height: BananSpacing.sm),
        _BreakdownRow(
          icon: Icons.delivery_dining_outlined,
          label: 'Giao hàng',
          trailing: '${fmt.format(split.delivery.revenue)} · '
              '${split.delivery.orders} đơn',
          fraction:
              totalOrders == 0 ? 0 : split.delivery.orders / totalOrders,
        ),
      ],
    );
  }
}

/// Order counts grouped by payment provider, with % share.
class _PaymentBreakdown extends StatelessWidget {
  const _PaymentBreakdown({required this.items});
  final List<Map<String, dynamic>> items;

  static String _label(String provider) {
    switch (provider.toUpperCase()) {
      case 'CASH':
        return 'Tiền mặt';
      case 'PAYOS':
        return 'PayOS';
      case 'VNPAY':
        return 'VNPay'; // legacy
      default:
        return provider;
    }
  }

  static IconData _icon(String provider) {
    switch (provider.toUpperCase()) {
      case 'CASH':
        return Icons.payments_outlined;
      case 'PAYOS':
        return Icons.qr_code_2_outlined;
      case 'VNPAY':
        return Icons.account_balance_outlined; // legacy
      default:
        return Icons.credit_card_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalOrders = items.fold<int>(
      0,
      (m, e) => m + ((e['orders'] as num?)?.toInt() ?? 0),
    );
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: BananSpacing.sm),
          _BreakdownRow(
            icon: _icon((items[i]['provider'] as String?) ?? ''),
            label: _label((items[i]['provider'] as String?) ?? '—'),
            trailing: '${(items[i]['orders'] as num?)?.toInt() ?? 0} đơn',
            fraction: totalOrders == 0
                ? 0
                : ((items[i]['orders'] as num?)?.toInt() ?? 0) / totalOrders,
          ),
        ],
      ],
    );
  }
}

/// Shared row used by the fulfillment + payment breakdowns: leading icon,
/// label, a proportional bar, and a trailing value + % share.
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.fraction,
  });

  final IconData icon;
  final String label;
  final String trailing;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final pct = (fraction.clamp(0.0, 1.0) * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: BananSpacing.sm),
            Expanded(
              child: Text(label, style: theme.textTheme.titleSmall),
            ),
            const SizedBox(width: BananSpacing.sm),
            Text(
              '$trailing · $pct%',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BananRadii.rlg,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: BananSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.daily, required this.fmt});
  final List<Map<String, dynamic>> daily;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = <FlSpot>[];
    for (var i = 0; i < daily.length; i++) {
      final v = (daily[i]['revenue'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), v));
    }
    final maxY = spots.fold<double>(0, (m, s) => s.y > m ? s.y : m);

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= daily.length) return const SizedBox.shrink();
                final date = DateTime.parse(daily[i]['date'] as String);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat.E().format(date),
                    style: theme.textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (daily.length - 1).toDouble().clamp(0, double.infinity),
        minY: 0,
        maxY: maxY == 0 ? 1 : maxY * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            color: theme.colorScheme.primary,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeakHoursChart extends StatelessWidget {
  const _PeakHoursChart({required this.hours});
  final List<Map<String, dynamic>> hours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxOrders = hours.fold<int>(
      0,
      (m, h) {
        final v = (h['orders'] as num?)?.toInt() ?? 0;
        return v > m ? v : m;
      },
    );

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 4,
              getTitlesWidget: (value, meta) {
                final hour = value.toInt();
                if (hour % 4 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}h',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        maxY: maxOrders == 0 ? 1 : (maxOrders * 1.2),
        barGroups: [
          for (final h in hours)
            BarChartGroupData(
              x: (h['hour'] as num?)?.toInt() ?? 0,
              barRods: [
                BarChartRodData(
                  toY: (h['orders'] as num?)?.toDouble() ?? 0,
                  color: theme.colorScheme.primary,
                  width: 8,
                  borderRadius: BananRadii.rxs,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BestSellersList extends StatelessWidget {
  const _BestSellersList({required this.items, required this.fmt});
  final List<Map<String, dynamic>> items;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: BananSpacing.lg),
        child: Text('Chưa có đơn hoàn thành trong khoảng thời gian này.'),
      );
    }
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BananSpacing.xs),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary
                      .withValues(alpha: 0.12),
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: BananSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i]['productName'] as String,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        '${items[i]['unitsSold']} đã bán · ${fmt.format(items[i]['revenue'])}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

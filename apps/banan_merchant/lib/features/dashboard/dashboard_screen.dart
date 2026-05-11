import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

final _summaryProvider = FutureProvider.autoDispose
    .family<MerchantSummary, String>((ref, range) async {
  final res = await ref.watch(analyticsApiProvider).merchantSummary(range: range);
  return res.when(
    success: (s) => s,
    failure: (f) => throw Exception(f.message ?? f.code),
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

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(_summaryProvider(_range));
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Orders',
            onPressed: () => context.go('/'),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Menu',
            onPressed: () => context.go('/menu'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_summaryProvider(_range)),
        ),
        data: (s) => _Body(
          summary: s,
          range: _range,
          onRange: (r) => setState(() => _range = r),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.summary,
    required this.range,
    required this.onRange,
  });

  final MerchantSummary summary;
  final String range;
  final ValueChanged<String> onRange;

  @override
  Widget build(BuildContext context) {
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

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: BananSpacing.md),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: BananSpacing.lg),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '24h', label: Text('24h')),
              ButtonSegment(value: '7d', label: Text('7 days')),
              ButtonSegment(value: '30d', label: Text('30 days')),
            ],
            selected: {range},
            onSelectionChanged: (s) => onRange(s.first),
          ),
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
                  label: 'Revenue',
                  value: fmt.format(revenue),
                  icon: Icons.payments_outlined,
                  intent: StatIntent.success,
                  hint: '$completed completed orders',
                ),
                StatCard(
                  label: 'Orders',
                  value: '$orders',
                  icon: Icons.receipt_long_outlined,
                ),
                StatCard(
                  label: 'Refund rate',
                  value: '${(refundRate * 100).toStringAsFixed(1)}%',
                  icon: Icons.refresh,
                  intent: refundRate > 0.1
                      ? StatIntent.danger
                      : StatIntent.neutral,
                ),
                StatCard(
                  label: 'Avg order value',
                  value: fmt.format(aov),
                  icon: Icons.trending_up,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: BananSpacing.xl),
        _Section(
          title: 'Revenue',
          child: SizedBox(
            height: 220,
            child: _RevenueChart(daily: summary.daily, fmt: fmt),
          ),
        ),
        const SizedBox(height: BananSpacing.xl),
        _Section(
          title: 'Best sellers',
          child: _BestSellersList(items: summary.bestSellers, fmt: fmt),
        ),
        const SizedBox(height: BananSpacing.xl),
        _Section(
          title: 'Peak hours',
          child: SizedBox(
            height: 180,
            child: _PeakHoursChart(hours: summary.peakHours),
          ),
        ),
        const SizedBox(height: BananSpacing.huge),
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
        child: Text('No completed orders in this range yet.'),
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
                        '${items[i]['unitsSold']} sold · ${fmt.format(items[i]['revenue'])}',
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

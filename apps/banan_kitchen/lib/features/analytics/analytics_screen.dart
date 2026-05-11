import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

final _summaryProvider = FutureProvider.autoDispose
    .family<KitchenAnalyticsSummary, String>((ref, range) async {
  final res = await ref
      .watch(analyticsApiProvider)
      .kitchenSummary(range: range);
  return res.when(
    success: (s) => s,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

class KitchenAnalyticsScreen extends ConsumerStatefulWidget {
  const KitchenAnalyticsScreen({super.key});

  @override
  ConsumerState<KitchenAnalyticsScreen> createState() =>
      _KitchenAnalyticsScreenState();
}

class _KitchenAnalyticsScreenState
    extends ConsumerState<KitchenAnalyticsScreen> {
  String _range = '7d';

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(_summaryProvider(_range));
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Kitchen Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Kanban',
            onPressed: () => context.go('/'),
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

  final KitchenAnalyticsSummary summary;
  final String range;
  final ValueChanged<String> onRange;

  @override
  Widget build(BuildContext context) {
    final t = summary.totals;
    final received = (t['received'] as num?)?.toInt() ?? 0;
    final inProgress = (t['inProgress'] as num?)?.toInt() ?? 0;
    final dispatched = (t['dispatched'] as num?)?.toInt() ?? 0;
    final avgMin = (t['avgDispatchMinutes'] as num?)?.toDouble() ?? 0;
    final capacity = (t['capacityUtilization'] as num?)?.toDouble() ?? 0;

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
                  label: 'Orders received',
                  value: '$received',
                  icon: Icons.move_to_inbox_outlined,
                ),
                StatCard(
                  label: 'In progress',
                  value: '$inProgress',
                  icon: Icons.kitchen_outlined,
                  intent: StatIntent.warning,
                ),
                StatCard(
                  label: 'Dispatched',
                  value: '$dispatched',
                  icon: Icons.local_shipping_outlined,
                  intent: StatIntent.success,
                ),
                StatCard(
                  label: 'Avg dispatch',
                  value: avgMin == 0 ? '—' : '${avgMin.toStringAsFixed(0)} min',
                  icon: Icons.timer_outlined,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: BananSpacing.xl),
        _Section(
          title: 'Daily production',
          child: SizedBox(
            height: 220,
            child: _DailyBarChart(daily: summary.daily),
          ),
        ),
        const SizedBox(height: BananSpacing.xl),
        _Section(
          title: 'Capacity utilization',
          child: _CapacityBar(value: capacity),
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

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({required this.daily});
  final List<Map<String, dynamic>> daily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxOrders = daily.fold<int>(
      0,
      (m, d) => ((d['orders'] as num?)?.toInt() ?? 0) > m
          ? ((d['orders'] as num?)?.toInt() ?? 0)
          : m,
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
        maxY: maxOrders == 0 ? 1 : (maxOrders * 1.2),
        barGroups: [
          for (var i = 0; i < daily.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (daily[i]['orders'] as num?)?.toDouble() ?? 0,
                  color: theme.colorScheme.primary,
                  width: 16,
                  borderRadius: BananRadii.rsm,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CapacityBar extends StatelessWidget {
  const _CapacityBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = value.clamp(0, 1).toDouble();
    final pct = (clamped * 100).toStringAsFixed(1);
    final color = clamped > 0.9
        ? BananColors.danger
        : clamped > 0.7
            ? BananColors.warning
            : BananColors.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$pct% of theoretical capacity'),
        const SizedBox(height: BananSpacing.sm),
        ClipRRect(
          borderRadius: BananRadii.rPill,
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 12,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: BananSpacing.xs),
        Text(
          'Capacity = capacityPerHour × 24 × days',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

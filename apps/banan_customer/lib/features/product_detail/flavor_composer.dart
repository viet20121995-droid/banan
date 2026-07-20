import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';

/// Inline flavour composer for macaron sets — the customer picks exactly
/// [pickCount] macarons from [options], repeats allowed. A sticky counter
/// shows "Đã chọn 3/5"; the parent gates "Add to cart" on
/// [isComplete]. Selection is a flavour→count map that flows into
/// `CartItem.personalization` as `{ "flavors": {...} }`.
class FlavorComposer extends StatelessWidget {
  const FlavorComposer({
    required this.options,
    required this.pickCount,
    required this.selection,
    required this.onChanged,
    super.key,
  });

  final List<String> options;
  final int pickCount;
  final Map<String, int> selection;
  final ValueChanged<Map<String, int>> onChanged;

  int get _total => selection.values.fold(0, (s, n) => s + n);
  bool get isComplete => _total == pickCount;

  void _bump(String flavor, int delta) {
    final next = {...selection};
    final cur = next[flavor] ?? 0;
    final v = cur + delta;
    // Don't exceed the set size in total; don't go below 0.
    if (v < 0) return;
    if (delta > 0 && _total >= pickCount) return;
    if (v == 0) {
      next.remove(flavor);
    } else {
      next[flavor] = v;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = pickCount - _total;
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Chọn vị macaron',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BananRadii.rPill,
                  color: isComplete
                      ? BananColors.success.withValues(alpha: 0.15)
                      : BananColors.gold.withValues(alpha: 0.18),
                ),
                child: Text(
                  'Đã chọn $_total/$pickCount',
                  style: TextStyle(
                    color: isComplete
                        ? BananColors.success
                        : BananColors.cocoa,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.xs),
          Text(
            isComplete
                ? 'Đủ rồi! Bạn có thể thêm vào giỏ.'
                : 'Còn $remaining cái, chọn thêm (có thể nhiều cái cùng vị).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: BananSpacing.sm),
          for (final flavor in options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      flavor,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: (selection[flavor] ?? 0) > 0
                        ? () => _bump(flavor, -1)
                        : null,
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${selection[flavor] ?? 0}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _total < pickCount
                        ? () => _bump(flavor, 1)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One-line summary of a flavour composition for order rows / cart.
/// `{ "Jasmine": 3, "Lemon": 2 }` → "3× Jasmine, 2× Lemon".
String summarizeFlavors(Map<String, dynamic> flavors) {
  final parts = <String>[];
  flavors.forEach((k, v) => parts.add('${(v as num).toInt()}× $k'));
  return parts.join(', ');
}

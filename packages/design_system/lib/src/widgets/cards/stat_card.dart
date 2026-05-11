import 'package:flutter/material.dart';

import '../../tokens/colors.dart';
import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';

/// A compact metric card for dashboards. Renders a label + value with an
/// optional icon and trend hint underneath. Designed to tile in a Wrap or
/// fixed-cross-axis-count grid.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    this.icon,
    this.hint,
    this.intent = StatIntent.neutral,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? hint;
  final StatIntent intent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accent(intent, theme);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(BananSpacing.xs),
                  decoration: BoxDecoration(
                    borderRadius: BananRadii.rsm,
                    color: accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, size: 16, color: accent),
                ),
                const SizedBox(width: BananSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.md),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: BananSpacing.xs),
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _accent(StatIntent i, ThemeData theme) {
    switch (i) {
      case StatIntent.neutral:
        return theme.colorScheme.primary;
      case StatIntent.success:
        return BananColors.success;
      case StatIntent.warning:
        return BananColors.warning;
      case StatIntent.danger:
        return BananColors.danger;
    }
  }
}

enum StatIntent { neutral, success, warning, danger }

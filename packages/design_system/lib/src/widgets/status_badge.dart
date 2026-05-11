import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radii.dart';
import '../tokens/spacing.dart';

/// Visual intent for a status pill — generic enough to be reused for orders,
/// payments, refunds, kitchen states.
enum StatusIntent { neutral, info, progress, success, warning, danger }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.intent,
    this.dense = false,
    super.key,
  });

  final String label;
  final StatusIntent intent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, border) = _palette(intent);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? BananSpacing.sm : BananSpacing.md,
        vertical: dense ? 2 : BananSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rPill,
        color: bg,
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: dense ? 11 : 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  (Color fg, Color bg, Color border) _palette(StatusIntent intent) {
    switch (intent) {
      case StatusIntent.neutral:
        return (
          BananColors.cocoaSoft,
          BananColors.surfaceDim,
          BananColors.outline,
        );
      case StatusIntent.info:
        return (
          BananColors.info,
          BananColors.info.withValues(alpha: 0.12),
          BananColors.info.withValues(alpha: 0.4),
        );
      case StatusIntent.progress:
        return (
          BananColors.primary,
          BananColors.primary.withValues(alpha: 0.10),
          BananColors.primary.withValues(alpha: 0.4),
        );
      case StatusIntent.success:
        return (
          BananColors.success,
          BananColors.success.withValues(alpha: 0.12),
          BananColors.success.withValues(alpha: 0.4),
        );
      case StatusIntent.warning:
        return (
          BananColors.warning,
          BananColors.warning.withValues(alpha: 0.14),
          BananColors.warning.withValues(alpha: 0.4),
        );
      case StatusIntent.danger:
        return (
          BananColors.danger,
          BananColors.danger.withValues(alpha: 0.10),
          BananColors.danger.withValues(alpha: 0.4),
        );
    }
  }
}

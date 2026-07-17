import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';

/// Explains why a screen someone can open is nonetheless read-only for them.
///
/// Several chain-wide settings are readable by MERCHANT_OWNER but writable only
/// by ADMIN (`@Roles(Role.ADMIN)` on the PATCH). Disabling the save button
/// alone reads as a bug; this says who it belongs to, so the owner asks an
/// admin instead of filing "the save button is broken".
class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: BananSpacing.md),
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: BananColors.gold.withValues(alpha: 0.12),
        border: Border.all(color: BananColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 20, color: BananColors.gold),
          const SizedBox(width: BananSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

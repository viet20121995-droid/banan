import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';

/// Editorial section heading used across the home page. Three parts:
///   - Tiny uppercase overline (eyebrow) in muted gold
///   - Large serif title in cocoa ink
///   - Optional one-line subtitle in soft grey
///   - Optional trailing widget (a "View all →" link or filter chip)
///
/// Below the title sits a short matcha accent rule, giving each section a
/// consistent "magazine" feel rather than a row of identical Text widgets.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.overline,
    this.subtitle,
    this.trailing,
    super.key,
  });

  /// Big title — uses display serif from the theme.
  final String title;

  /// Optional uppercase eyebrow — short, contextual ("BÁNH MỚI", "HÔM NAY").
  final String? overline;

  /// Optional muted description below the title.
  final String? subtitle;

  /// Optional widget on the right (link / button / chip).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (overline != null && overline!.trim().isNotEmpty) ...[
                      Text(
                        overline!.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: BananColors.gold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(title, style: theme.textTheme.headlineSmall),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: BananSpacing.md),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: BananSpacing.sm),
          // Matcha hairline accent — short, left-aligned, decorative.
          Container(
            height: 2,
            width: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

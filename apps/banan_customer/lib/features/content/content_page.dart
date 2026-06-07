import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';

/// One titled block of body paragraphs in a static content page.
class ContentSection {
  const ContentSection(this.heading, this.paragraphs);
  final String heading;
  final List<String> paragraphs;
}

/// Shared scaffold for long-form static pages (Privacy, Terms, About …).
/// Renders a centred, max-width reading column with consistent typography
/// so every legal / informational page looks the same.
class ContentPage extends StatelessWidget {
  const ContentPage({
    required this.title,
    required this.sections,
    this.intro,
    this.updatedLabel,
    this.footer,
    super.key,
  });

  final String title;
  final String? intro;
  final String? updatedLabel;
  final List<ContentSection> sections;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Compact, single-column document layout — tight enough that each policy
    // page fits in one continuous page for a clean full-page screenshot
    // (e.g. for the Bộ Công Thương dossier), while staying readable.
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      height: 1.4,
      color: theme.colorScheme.onSurface,
    );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: BananSpacing.lg,
              vertical: BananSpacing.md,
            ),
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (updatedLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  updatedLabel!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
              if (intro != null) ...[
                const SizedBox(height: BananSpacing.sm),
                Text(intro!, style: bodyStyle),
              ],
              const SizedBox(height: BananSpacing.md),
              for (final s in sections) ...[
                Text(
                  s.heading,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                for (final p in s.paragraphs) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: bodyStyle),
                      Expanded(child: Text(p, style: bodyStyle)),
                    ],
                  ),
                  const SizedBox(height: 3),
                ],
                const SizedBox(height: BananSpacing.sm),
              ],
              if (footer != null) ...[
                const SizedBox(height: BananSpacing.sm),
                footer!,
              ],
              const SizedBox(height: BananSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

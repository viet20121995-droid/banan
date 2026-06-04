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
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(BananSpacing.xl),
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              if (updatedLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  updatedLabel!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
              if (intro != null) ...[
                const SizedBox(height: BananSpacing.md),
                Text(intro!, style: theme.textTheme.bodyLarge),
              ],
              const SizedBox(height: BananSpacing.lg),
              for (final s in sections) ...[
                Text(s.heading, style: theme.textTheme.titleLarge),
                const SizedBox(height: BananSpacing.xs),
                for (final p in s.paragraphs) ...[
                  Text(
                    p,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: BananSpacing.sm),
                ],
                const SizedBox(height: BananSpacing.md),
              ],
              if (footer != null) ...[
                const SizedBox(height: BananSpacing.md),
                footer!,
              ],
              const SizedBox(height: BananSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

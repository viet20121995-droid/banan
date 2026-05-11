import 'package:flutter/material.dart';

import '../../tokens/spacing.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(BananSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: BananSpacing.lg),
              Text(
                title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: BananSpacing.sm),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: BananSpacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

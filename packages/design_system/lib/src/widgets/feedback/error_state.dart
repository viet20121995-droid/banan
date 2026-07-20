import 'package:flutter/material.dart';

import '../../tokens/spacing.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.message,
    this.title = 'Có lỗi xảy ra',
    this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  /// Callers commonly pass `e.toString()` where `e` is an `Exception('…')`,
  /// which renders a leaked "Exception: " prefix. Strip it here once instead
  /// of at every call site.
  String get _displayMessage {
    const prefix = 'Exception: ';
    return message.startsWith(prefix)
        ? message.substring(prefix.length)
        : message;
  }

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
              Icon(
                Icons.sentiment_dissatisfied_rounded,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: BananSpacing.lg),
              Text(
                title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BananSpacing.sm),
              Text(
                _displayMessage,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: BananSpacing.xl),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử lại'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

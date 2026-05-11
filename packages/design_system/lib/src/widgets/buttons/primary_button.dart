import 'package:flutter/material.dart';

import '../../tokens/spacing.dart';

/// Primary CTA button. Supports a loading state that disables the button and
/// renders a small spinner without layout jump.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;

    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: BananSpacing.sm),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = ElevatedButton(
      onPressed: disabled ? null : onPressed,
      child: child,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';

/// Brand lockup for the app bar: circular logo + "Banan Fukuoka Saigon".
///
/// The logo is loaded from `assets/brand/logo.png`. If that file isn't
/// present yet (or fails to decode) we fall back to a tasteful text-only
/// wordmark so the app never shows a broken-image box.
class BananBrand extends StatelessWidget {
  const BananBrand({this.compact = false, super.key});

  /// When true, shows just the logo mark (used on very narrow screens).
  final bool compact;

  static const _assetPath = 'assets/brand/logo.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ClipOval ensures any stray white in the source PNG corners gets
    // clipped — the visible mark stays a clean green circle even if the
    // logo file ships with a square white backdrop.
    final mark = ClipOval(
      child: Image.asset(
        _assetPath,
        height: 36,
        width: 36,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 36,
          width: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: BananColors.primary,
          ),
          alignment: Alignment.center,
          child: const Text(
            'B',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );

    if (compact) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: BananSpacing.sm),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Banan',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: BananColors.primary,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'FUKUOKA · SAIGON',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: BananColors.cocoaSoft,
                  letterSpacing: 1.6,
                  fontSize: 9,
                  height: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

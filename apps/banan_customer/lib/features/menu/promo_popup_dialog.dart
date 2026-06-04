import 'dart:async';
import 'dart:math' as math;

import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compact, kissaten-flavoured scrapbook-style promo popup. Smaller than
/// a typical full-screen modal so the menu stays partially visible
/// behind it; image is 4:3 instead of 16:9, max width caps at ~320dp.
///
/// Entrance is a scale + fade with a soft `easeOutBack` overshoot so the
/// card "lands" like a sticker dropped onto a scrapbook page. A tiny
/// washi-tape strip at the top sells the metaphor.
class PromoPopupDialog extends StatefulWidget {
  const PromoPopupDialog({required this.popup, super.key});

  final PromoPopup popup;

  /// Helper that wraps `showGeneralDialog` so the menu mount-point doesn't
  /// have to know about the bespoke transition.
  static Future<void> show(BuildContext context, PromoPopup popup) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Đóng popup',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, __, ___) => PromoPopupDialog(popup: popup),
      transitionBuilder: (context, anim, _, child) {
        // Drop-in scrapbook entrance: scale + fade + a touch of rotation
        // so the card feels hand-placed rather than slid in mechanically.
        final eased = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: anim,
          child: Transform.rotate(
            angle: (1 - eased.value) * 0.06, // ~3.4° offset on entry
            child: Transform.scale(
              scale: 0.85 + eased.value * 0.15,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<PromoPopupDialog> createState() => _PromoPopupDialogState();
}

class _PromoPopupDialogState extends State<PromoPopupDialog> {
  Timer? _ticker;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.popup.countdownSeconds;
    if (_remaining > 0) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _remaining -= 1);
        if (_remaining <= 0) {
          _ticker?.cancel();
          Navigator.of(context).maybePop();
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _openCta() async {
    final url = widget.popup.ctaUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    Navigator.of(context).maybePop();
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final popup = widget.popup;
    final size = MediaQuery.sizeOf(context);
    // Tight max width — feels like a card, not a sheet.
    final maxWidth = math.min<double>(size.width - 32, 320);
    final hasImage =
        popup.imageUrl != null && popup.imageUrl!.trim().isNotEmpty;
    final hasCta = popup.ctaLabel != null &&
        popup.ctaLabel!.trim().isNotEmpty &&
        popup.ctaUrl != null &&
        popup.ctaUrl!.trim().isNotEmpty;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          // Slight resting tilt — sells the "stuck onto a scrapbook page"
          // feel without making text hard to read.
          child: Transform.rotate(
            angle: -0.012, // ~-0.7°
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Card body ──────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BananRadii.rlg,
                    border: Border.all(
                      color: theme.dividerTheme.color ?? Colors.black12,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasImage)
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.network(
                            popup.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: BananColors.surfaceDim,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.image_outlined,
                                size: 32,
                                color: BananColors.cocoaSoft,
                              ),
                            ),
                          ),
                        )
                      else
                        // No image: a thin coloured band keeps the card
                        // grounded at the top without resorting to the
                        // (now-retired) seigaiha wave decoration.
                        Container(
                          height: 12,
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.18),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          BananSpacing.lg,
                          BananSpacing.lg,
                          BananSpacing.lg,
                          BananSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              popup.title,
                              style: theme.textTheme.titleLarge,
                            ),
                            if (popup.body.trim().isNotEmpty) ...[
                              const SizedBox(height: BananSpacing.sm),
                              Text(
                                popup.body,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                            if (hasCta) ...[
                              const SizedBox(height: BananSpacing.md),
                              FilledButton.icon(
                                onPressed: _openCta,
                                icon: const Icon(
                                  Icons.local_offer_outlined,
                                  size: 16,
                                ),
                                label: Text(popup.ctaLabel!),
                              ),
                            ],
                            if (popup.countdownSeconds > 0) ...[
                              const SizedBox(height: BananSpacing.md),
                              _Countdown(
                                remaining: _remaining,
                                total: popup.countdownSeconds,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Washi tape strip at the top — scrapbook decoration ──
                Positioned(
                  top: -6,
                  left: 32,
                  right: 32,
                  child: IgnorePointer(
                    child: Transform.rotate(
                      angle: 0.02,
                      child: const _WashiTape(),
                    ),
                  ),
                ),

                // ── Close button (always available) ────────────────────
                Positioned(
                  top: -10,
                  right: -10,
                  child: Material(
                    color: theme.colorScheme.surface,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: IconButton(
                      iconSize: 18,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: 'Đóng',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact countdown row with a thin progress bar. Visible only when the
/// admin set a non-zero `countdownSeconds`.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.remaining, required this.total});
  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: 12,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 4),
            Text(
              'Tự đóng sau ${remaining}s',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: total == 0 ? 0 : remaining / total),
            duration: const Duration(milliseconds: 950),
            curve: Curves.linear,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor:
                  theme.colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
        ),
      ],
    );
  }
}

/// Faux washi-tape strip — a small striped rectangle suggesting the popup
/// is "taped" onto a scrapbook page. Pure decoration; ignores pointers.
class _WashiTape extends StatelessWidget {
  const _WashiTape();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      decoration: BoxDecoration(
        color: BananColors.gold.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: CustomPaint(
          painter: _WashiStripePainter(),
        ),
      ),
    );
  }
}

class _WashiStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle diagonal stripes — evokes patterned tape without competing
    // with the card content.
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.6;
    const step = 8.0;
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WashiStripePainter oldDelegate) => false;
}

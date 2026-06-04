import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/web_storage.dart' as web_storage;

const _kCookieKey = 'banan_cookie_consent';

enum CookieConsent { unknown, essentialOnly, all }

/// Persisted (web localStorage) cookie-consent choice. Default is
/// [CookieConsent.unknown] until the shopper picks — at which point the
/// banner stops showing. Privacy-preserving default: "essential only".
class CookieConsentNotifier extends StateNotifier<CookieConsent> {
  CookieConsentNotifier() : super(_load());

  static CookieConsent _load() {
    switch (web_storage.read(_kCookieKey)) {
      case 'all':
        return CookieConsent.all;
      case 'essential':
        return CookieConsent.essentialOnly;
      default:
        return CookieConsent.unknown;
    }
  }

  void acceptAll() {
    web_storage.write(_kCookieKey, 'all');
    state = CookieConsent.all;
  }

  void essentialOnly() {
    web_storage.write(_kCookieKey, 'essential');
    state = CookieConsent.essentialOnly;
  }
}

final cookieConsentProvider =
    StateNotifierProvider<CookieConsentNotifier, CookieConsent>(
  (_) => CookieConsentNotifier(),
);

/// Bottom consent bar. Renders nothing once a choice has been made.
/// Mounted app-wide via the MaterialApp builder so it appears on every page.
class CookieConsentBanner extends ConsumerWidget {
  const CookieConsentBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(cookieConsentProvider);
    if (consent != CookieConsent.unknown) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final notifier = ref.read(cookieConsentProvider.notifier);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BananSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Material(
              elevation: 8,
              borderRadius: BananRadii.rlg,
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(BananSpacing.lg),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: BananSpacing.sm,
                  spacing: BananSpacing.md,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Text.rich(
                        TextSpan(
                          text: 'Chúng tôi dùng cookie cần thiết để website '
                              'hoạt động. Bạn có thể chọn bật thêm cookie phân '
                              'tích. Xem ',
                          style: theme.textTheme.bodySmall,
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: InkWell(
                                onTap: () => context.push('/privacy'),
                                child: Text(
                                  'Chính sách bảo mật',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: notifier.essentialOnly,
                          child: const Text('Chỉ cần thiết'),
                        ),
                        const SizedBox(width: BananSpacing.sm),
                        FilledButton(
                          onPressed: notifier.acceptAll,
                          child: const Text('Chấp nhận tất cả'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

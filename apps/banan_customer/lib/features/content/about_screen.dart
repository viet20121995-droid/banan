// Fallback content uses multi-line implicit string concatenation inside the
// section lists — deliberate, not a missing comma.
// Japanese copy has no spaces between words, so adjacent JA strings join
// without whitespace on purpose.
// ignore_for_file: no_adjacent_strings_in_list, require_trailing_commas
// ignore_for_file: missing_whitespace_between_adjacent_strings
import 'package:banan_data/banan_data.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'content_page.dart';

const _fallbackIntroVi =
    'Banan Fukuoka Saigon mang tinh thần kissaten Nhật Bản đến Sài Gòn, '
    'nơi mỗi chiếc bánh được làm thủ công, tươi mỗi ngày.';

const _fallbackSectionsVi = <ContentSection>[
  ContentSection('Câu chuyện của chúng tôi', [
    'Bắt đầu từ tình yêu với những tiệm cà phê – bánh ngọt nhỏ ở Fukuoka, '
        'Banan mang hương vị tinh tế ấy về Việt Nam.',
  ]),
  ContentSection('Hệ thống chi nhánh', [
    'Banan có nhiều chi nhánh tại TP.HCM, phục vụ cả nhận tại quầy và giao '
        'hàng. Xem chi tiết ở trang Chi nhánh.',
  ]),
];

const _fallbackIntroEn =
    'Banan Fukuoka Saigon brings the spirit of the Japanese kissaten to '
    'Saigon — every cake handcrafted, baked fresh daily.';

const _fallbackSectionsEn = <ContentSection>[
  ContentSection('Our story', [
    'Born from a love of the small coffee-and-pastry shops of Fukuoka, '
        'Banan brings that refined taste to Vietnam.',
  ]),
  ContentSection('Our stores', [
    'Banan has several stores across Ho Chi Minh City, serving both '
        'counter pickup and delivery. See the Locations page for details.',
  ]),
];

const _fallbackIntroJa = 'Banan Fukuoka Saigonは、日本の喫茶店の心をサイゴンにお届けします。'
    'ケーキはすべて手作りで、毎日焼き上げています。';

const _fallbackSectionsJa = <ContentSection>[
  ContentSection('私たちの物語', [
    '福岡の小さな喫茶店や洋菓子店への愛から生まれたBananは、'
        'その繊細な味わいをベトナムにお届けしています。',
  ]),
  ContentSection('店舗のご案内', [
    'Bananはホーチミン市内に複数の店舗があり、店頭でのお受け取りと'
        '配達の両方に対応しています。詳しくは店舗一覧ページをご覧ください。',
  ]),
];

/// Câu chuyện thương hiệu Banan — nội dung do merchant quản lý
/// (Cài đặt → Nội dung trang); fallback nội dung mặc định.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aboutContentProvider);
    final str = ref.watch(stringsProvider);
    final loc = ref.watch(localeProvider);
    final fallbackIntro = switch (loc) {
      AppLocale.en => _fallbackIntroEn,
      AppLocale.ja => _fallbackIntroJa,
      AppLocale.vi => _fallbackIntroVi,
    };
    final fallbackSections = switch (loc) {
      AppLocale.en => _fallbackSectionsEn,
      AppLocale.ja => _fallbackSectionsJa,
      AppLocale.vi => _fallbackSectionsVi,
    };

    // Merchant-managed content is written in Vietnamese only, so it is
    // shown only for the Vietnamese locale; EN/JA use the built-in text.
    final (intro, sections) = loc != AppLocale.vi
        ? (fallbackIntro, fallbackSections)
        : async.maybeWhen(
            data: (c) {
              final secs = c.aboutSections
                  .map(
                    (s) => ContentSection(
                      s.heading,
                      s.body
                          .split('\n\n')
                          .map((p) => p.trim())
                          .where((p) => p.isNotEmpty)
                          .toList(),
                    ),
                  )
                  .toList();
              final intro =
                  c.aboutIntro.isNotEmpty ? c.aboutIntro : fallbackIntro;
              return (intro, secs.isNotEmpty ? secs : fallbackSections);
            },
            orElse: () => (fallbackIntro, fallbackSections),
          );

    return ContentPage(
      title: str.aboutTitle,
      intro: intro,
      sections: sections,
      footer: Builder(
        builder: (context) => Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => context.push('/locations'),
            icon: const Icon(Icons.storefront_outlined),
            label: Text(str.viewLocations),
          ),
        ),
      ),
    );
  }
}

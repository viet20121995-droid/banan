// Fallback content uses multi-line implicit string concatenation inside the
// section lists — deliberate, not a missing comma.
// ignore_for_file: no_adjacent_strings_in_list, require_trailing_commas
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

/// Câu chuyện thương hiệu Banan — nội dung do merchant quản lý
/// (Cài đặt → Nội dung trang); fallback nội dung mặc định.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aboutContentProvider);
    final str = ref.watch(stringsProvider);
    final en = ref.watch(localeProvider) == AppLocale.en;
    final fallbackIntro = en ? _fallbackIntroEn : _fallbackIntroVi;
    final fallbackSections = en ? _fallbackSectionsEn : _fallbackSectionsVi;

    final (intro, sections) = async.maybeWhen(
      data: (c) {
        final secs = c.aboutSections
            .map((s) => ContentSection(
                  s.heading,
                  s.body
                      .split('\n\n')
                      .map((p) => p.trim())
                      .where((p) => p.isNotEmpty)
                      .toList(),
                ))
            .toList();
        final intro = c.aboutIntro.isNotEmpty ? c.aboutIntro : fallbackIntro;
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

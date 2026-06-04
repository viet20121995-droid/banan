// Fallback content uses multi-line implicit string concatenation inside the
// section lists — deliberate, not a missing comma.
// ignore_for_file: no_adjacent_strings_in_list, require_trailing_commas
import 'package:banan_data/banan_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'content_page.dart';

const _fallbackIntro =
    'Banan Fukuoka Saigon mang tinh thần kissaten Nhật Bản đến Sài Gòn — '
    'nơi mỗi chiếc bánh được làm thủ công, tươi mỗi ngày.';

const _fallbackSections = <ContentSection>[
  ContentSection('Câu chuyện của chúng tôi', [
    'Bắt đầu từ tình yêu với những tiệm cà phê – bánh ngọt nhỏ ở Fukuoka, '
        'Banan mang hương vị tinh tế ấy về Việt Nam.',
  ]),
  ContentSection('Hệ thống chi nhánh', [
    'Banan có nhiều chi nhánh tại TP.HCM, phục vụ cả nhận tại quầy và giao '
        'hàng. Xem chi tiết ở trang Chi nhánh.',
  ]),
];

/// Câu chuyện thương hiệu Banan — nội dung do merchant quản lý
/// (Cài đặt → Nội dung trang); fallback nội dung mặc định.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aboutContentProvider);

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
        final intro = c.aboutIntro.isNotEmpty ? c.aboutIntro : _fallbackIntro;
        return (intro, secs.isNotEmpty ? secs : _fallbackSections);
      },
      orElse: () => (_fallbackIntro, _fallbackSections),
    );

    return ContentPage(
      title: 'Về Banan',
      intro: intro,
      sections: sections,
      footer: Builder(
        builder: (context) => Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => context.push('/locations'),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Xem các chi nhánh'),
          ),
        ),
      ),
    );
  }
}

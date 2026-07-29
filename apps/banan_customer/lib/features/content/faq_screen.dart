import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _Qa {
  const _Qa(this.q, this.a);
  final String q;
  final String a;
}

/// Client-side fallback — shown only if the backend returns no FAQ items
/// (e.g. merchant cleared everything). Normally the merchant-managed
/// content from `faqContentProvider` is used.
const _fallbackVi = <_Qa>[
  _Qa(
    'Tôi đặt bánh sinh nhật trước bao lâu?',
    'Bánh sinh nhật và các set theo yêu cầu cần đặt trước theo thời gian '
        'chuẩn bị hiển thị trên trang sản phẩm (thường 1–2 ngày). Bạn chọn '
        'ngày/giờ nhận ở bước thanh toán.',
  ),
  _Qa(
    'Tôi có thể ghi chữ lên bánh và chọn số nến không?',
    'Có. Với bánh thuộc bộ sưu tập sinh nhật, bấm dấu "+" hoặc mở trang sản '
        'phẩm để cá nhân hoá: chữ trên bánh, số nến và ghi chú cho thợ bánh.',
  ),
  _Qa(
    'Tôi muốn huỷ đơn thì làm sao?',
    'Vào "Đơn hàng của tôi", mở đơn và bấm Huỷ khi đơn còn ở trạng thái '
        '"Chờ xác nhận" hoặc "Đã nhận".',
  ),
];

const _fallbackEn = <_Qa>[
  _Qa(
    'How far ahead should I order a birthday cake?',
    'Birthday cakes and custom sets need to be ordered ahead per the '
        'preparation time shown on the product page (usually 1–2 days). '
        'You pick the date/time at checkout.',
  ),
  _Qa(
    'Can I add text on the cake and choose candles?',
    'Yes. For cakes in the birthday collection, tap "+" or open the '
        'product page to personalize: text on the cake, candles and a note '
        'for the baker.',
  ),
  _Qa(
    'How do I cancel an order?',
    'Go to "My orders", open the order and tap Cancel while it is still '
        '"Pending" or "Accepted".',
  ),
];

/// Trung tâm trợ giúp — câu hỏi thường gặp (FAQ). Nội dung do merchant
/// quản lý (Cài đặt → Nội dung trang); fallback nội dung mặc định.
class FaqScreen extends ConsumerWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(faqContentProvider);
    final s = ref.watch(stringsProvider);
    final fallback = ref.watch(localeProvider) == AppLocale.en
        ? _fallbackEn
        : _fallbackVi;

    final items = async.maybeWhen(
      data: (c) => c.faqItems.isNotEmpty
          ? c.faqItems.map((e) => _Qa(e.q, e.a)).toList()
          : fallback,
      orElse: () => fallback,
    );

    return Scaffold(
      appBar: AppBar(title: Text(s.faqTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            children: [
              Text(
                s.faqTitle,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: BananSpacing.md),
              for (final qa in items)
                Card(
                  margin: const EdgeInsets.only(bottom: BananSpacing.sm),
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    title: Text(qa.q, style: theme.textTheme.titleSmall),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      BananSpacing.lg,
                      0,
                      BananSpacing.lg,
                      BananSpacing.lg,
                    ),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        qa.a,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: BananSpacing.lg),
              Center(
                child: TextButton.icon(
                  onPressed: () => context.push('/contact'),
                  icon: const Icon(Icons.support_agent_outlined),
                  label: Text(s.faqNotFound),
                ),
              ),
              const SizedBox(height: BananSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

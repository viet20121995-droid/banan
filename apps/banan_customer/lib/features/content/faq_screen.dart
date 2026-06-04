import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
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
const _fallback = <_Qa>[
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

/// Trung tâm trợ giúp — câu hỏi thường gặp (FAQ). Nội dung do merchant
/// quản lý (Cài đặt → Nội dung trang); fallback nội dung mặc định.
class FaqScreen extends ConsumerWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(faqContentProvider);

    final items = async.maybeWhen(
      data: (c) => c.faqItems.isNotEmpty
          ? c.faqItems.map((e) => _Qa(e.q, e.a)).toList()
          : _fallback,
      orElse: () => _fallback,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Câu hỏi thường gặp')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            children: [
              Text(
                'Câu hỏi thường gặp',
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
                  label: const Text('Không thấy câu trả lời? Liên hệ chúng tôi'),
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

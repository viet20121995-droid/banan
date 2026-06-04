import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

/// Provider keyed by status — merchant flips tabs to refilter the list.
final _reviewsModeratorProvider =
    FutureProvider.autoDispose.family<ReviewPage, ReviewStatus?>(
  (ref, status) async {
    final api = ref.watch(reviewsApiProvider);
    final res = await api.moderatorList(status: status);
    return res.when(
      success: (page) => page,
      failure: (f) => throw Exception(f.message ?? f.code),
    );
  },
);

/// Merchant moderation queue for product reviews.
///
/// Layout: ChoiceChip tabs (Tất cả / Chờ duyệt / Đã đăng / Ẩn) + a list of
/// review rows. Each row exposes the rating, body, product, author, and
/// publish / reject actions that PATCH `/merchant/reviews/:id/moderate`.
class ReviewsModerationScreen extends ConsumerStatefulWidget {
  const ReviewsModerationScreen({super.key});

  @override
  ConsumerState<ReviewsModerationScreen> createState() =>
      _ReviewsModerationScreenState();
}

class _ReviewsModerationScreenState
    extends ConsumerState<ReviewsModerationScreen> {
  /// `null` = "Tất cả" (no filter).
  ReviewStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_reviewsModeratorProvider(_filter));
    return MerchantShell(
      title: 'Đánh giá khách hàng',
      onRefresh: () async => ref.invalidate(_reviewsModeratorProvider(_filter)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BananSpacing.lg,
              BananSpacing.md,
              BananSpacing.lg,
              0,
            ),
            child: Wrap(
              spacing: BananSpacing.sm,
              children: [
                _filterChip(null, 'Tất cả'),
                _filterChip(ReviewStatus.pending, 'Chờ duyệt'),
                _filterChip(ReviewStatus.published, 'Đã đăng'),
                _filterChip(ReviewStatus.rejected, 'Đã ẩn'),
              ],
            ),
          ),
          const SizedBox(height: BananSpacing.md),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(_reviewsModeratorProvider(_filter)),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyState(
                    title: 'Chưa có đánh giá nào.',
                    message:
                        'Khi khách hàng đánh giá sản phẩm sau khi nhận hàng, '
                        'các đánh giá sẽ xuất hiện ở đây để bạn kiểm duyệt.',
                    icon: Icons.star_border_rounded,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(BananSpacing.lg),
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: BananSpacing.md),
                  itemBuilder: (_, i) => _ReviewRow(
                    review: page.items[i],
                    onModerated: () => ref
                        .invalidate(_reviewsModeratorProvider(_filter)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(ReviewStatus? value, String label) {
    return ChoiceChip(
      selected: _filter == value,
      label: Text(label),
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}

class _ReviewRow extends ConsumerStatefulWidget {
  const _ReviewRow({required this.review, required this.onModerated});

  final Review review;
  final VoidCallback onModerated;

  @override
  ConsumerState<_ReviewRow> createState() => _ReviewRowState();
}

class _ReviewRowState extends ConsumerState<_ReviewRow> {
  bool _saving = false;

  Future<void> _moderate(ReviewStatus next) async {
    String? note;
    if (next == ReviewStatus.rejected) {
      note = await _askForNote();
      if (note == null) return; // cancelled
    }
    setState(() => _saving = true);
    final res = await ref.read(reviewsApiProvider).moderate(
          widget.review.id,
          status: next,
          moderationNote: note,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next == ReviewStatus.published
                  ? 'Đã đăng đánh giá.'
                  : next == ReviewStatus.rejected
                      ? 'Đã ẩn đánh giá.'
                      : 'Đánh giá quay về trạng thái chờ duyệt.',
            ),
          ),
        );
        widget.onModerated();
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authFailureMessage(f))),
      ),
    );
  }

  Future<String?> _askForNote() async {
    final controller = TextEditingController();
    final saved = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Ghi chú ẩn đánh giá'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 280,
          decoration: const InputDecoration(
            hintText: 'Lý do ẩn (chỉ nội bộ thấy)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(controller.text.trim()),
            child: const Text('Ẩn đánh giá'),
          ),
        ],
      ),
    );
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.review;
    final df = DateFormat('dd/MM/yyyy HH:mm', 'vi_VN');
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BananRadii.rmd,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (r.productImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    r.productImage!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 44),
                  ),
                ),
              const SizedBox(width: BananSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.productName ?? 'Sản phẩm',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${r.userFullName ?? 'Khách'} · ${df.format(r.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: r.status),
            ],
          ),
          const SizedBox(height: BananSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  i < r.rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 16,
                  color: BananColors.gold,
                ),
            ],
          ),
          if ((r.body ?? '').isNotEmpty) ...[
            const SizedBox(height: BananSpacing.xs),
            Text(r.body!, style: theme.textTheme.bodyMedium),
          ],
          if (r.images.isNotEmpty) ...[
            const SizedBox(height: BananSpacing.sm),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: r.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    r.images[i],
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: BananSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_saving)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                if (r.status != ReviewStatus.published)
                  TextButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Đăng'),
                    onPressed: () => _moderate(ReviewStatus.published),
                  ),
                if (r.status != ReviewStatus.rejected)
                  TextButton.icon(
                    icon: const Icon(Icons.visibility_off_outlined, size: 16),
                    label: const Text('Ẩn'),
                    onPressed: () => _moderate(ReviewStatus.rejected),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final ReviewStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ReviewStatus.pending => 'Chờ duyệt',
      ReviewStatus.published => 'Đã đăng',
      ReviewStatus.rejected => 'Đã ẩn',
    };
    final intent = switch (status) {
      ReviewStatus.pending => StatusIntent.warning,
      ReviewStatus.published => StatusIntent.success,
      ReviewStatus.rejected => StatusIntent.danger,
    };
    return StatusBadge(label: label, intent: intent, dense: true);
  }
}

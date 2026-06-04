import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

final _bundlesListProvider =
    FutureProvider.autoDispose<List<Bundle>>((ref) async {
  final res = await ref.watch(bundlesApiProvider).merchantList();
  return res.when(
    success: (l) => l,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

/// Merchant view of every combo (including inactive). Tap row → editor.
/// FAB "Combo mới" creates a fresh draft.
class BundlesListScreen extends ConsumerWidget {
  const BundlesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_bundlesListProvider);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return MerchantShell(
      title: 'Combo',
      onRefresh: () async => ref.invalidate(_bundlesListProvider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/bundles/new'),
        icon: const Icon(Icons.add),
        label: const Text('Combo mới'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_bundlesListProvider),
        ),
        data: (bundles) {
          if (bundles.isEmpty) {
            return const EmptyState(
              title: 'Chưa có combo nào',
              message:
                  'Tạo combo đầu tiên bằng cách bấm "Combo mới" — chọn '
                  'các sản phẩm + đặt giá set, hệ thống tự tính phần khách '
                  'tiết kiệm.',
              icon: Icons.local_offer_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_bundlesListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                BananSpacing.lg,
                BananSpacing.md,
                BananSpacing.lg,
                96,
              ),
              itemCount: bundles.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: BananSpacing.md),
              itemBuilder: (_, i) => _BundleRow(
                bundle: bundles[i],
                fmt: fmt,
                onTap: () => context.push('/bundles/${bundles[i].id}'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BundleRow extends StatelessWidget {
  const _BundleRow({
    required this.bundle,
    required this.fmt,
    required this.onTap,
  });
  final Bundle bundle;
  final NumberFormat fmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BananRadii.rlg,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rlg,
          color: theme.colorScheme.surface,
          border: Border.all(
            color: theme.dividerTheme.color ?? Colors.black12,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BananRadii.rmd,
              child: SizedBox(
                width: 72,
                height: 72,
                child: bundle.imageUrl == null || bundle.imageUrl!.isEmpty
                    ? Container(
                        color: BananColors.surfaceDim,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.local_offer_outlined,
                          color: BananColors.cocoaSoft,
                        ),
                      )
                    : Image.network(bundle.imageUrl!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: BananSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bundle.name,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!bundle.isActive)
                        const Padding(
                          padding: EdgeInsets.only(left: BananSpacing.xs),
                          child: StatusBadge(
                            label: 'Tạm ẩn',
                            intent: StatusIntent.warning,
                            dense: true,
                          ),
                        )
                      else if (bundle.isPinnedToHome)
                        const Padding(
                          padding: EdgeInsets.only(left: BananSpacing.xs),
                          child: StatusBadge(
                            label: 'Trang chủ',
                            intent: StatusIntent.success,
                            dense: true,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bundle.items
                        .map((it) =>
                            '${it.quantity}× ${it.product?.name ?? "?"}')
                        .join(' + '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fmt.format(bundle.priceVnd),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The customer's voucher wallet — three tabs (Khả dụng / Đã dùng / Hết hạn)
/// backed by [voucherWalletProvider] (GET /coupons/mine). Each card shows a
/// discount summary, the redeemable code with a copy button, the minimum
/// subtotal and the expiry date.
class VoucherWalletScreen extends ConsumerWidget {
  const VoucherWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(voucherWalletProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ví voucher'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Khả dụng'),
              Tab(text: 'Đã dùng'),
              Tab(text: 'Hết hạn'),
            ],
          ),
        ),
        body: walletAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(voucherWalletProvider),
          ),
          data: (wallet) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(voucherWalletProvider),
            child: TabBarView(
              children: [
                _VoucherList(
                  vouchers: wallet.available,
                  emptyMessage: 'Bạn chưa có voucher nào khả dụng.',
                ),
                _VoucherList(
                  vouchers: wallet.used,
                  emptyMessage: 'Bạn chưa dùng voucher nào.',
                  dimmed: true,
                ),
                _VoucherList(
                  vouchers: wallet.expired,
                  emptyMessage: 'Không có voucher nào hết hạn.',
                  dimmed: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoucherList extends StatelessWidget {
  const _VoucherList({
    required this.vouchers,
    required this.emptyMessage,
    this.dimmed = false,
  });

  final List<Voucher> vouchers;
  final String emptyMessage;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    if (vouchers.isEmpty) {
      // Stay scrollable so pull-to-refresh works on an empty tab.
      return ListView(
        children: [
          const SizedBox(height: BananSpacing.xxl),
          EmptyState(
            title: 'Chưa có voucher',
            message: emptyMessage,
            icon: Icons.confirmation_number_outlined,
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(BananSpacing.lg),
      itemCount: vouchers.length,
      separatorBuilder: (_, __) => const SizedBox(height: BananSpacing.md),
      itemBuilder: (_, i) => _VoucherCard(voucher: vouchers[i], dimmed: dimmed),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher, required this.dimmed});

  final Voucher voucher;
  final bool dimmed;

  static final _vnd =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  /// Renders a number without a trailing ".0".
  static String _numText(num n) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toString();
  }

  String get _discountSummary {
    switch (voucher.type) {
      case CouponType.percent:
        return 'Giảm ${_numText(voucher.value)}%';
      case CouponType.fixed:
        return 'Giảm ${_vnd.format(voucher.value)}';
      case CouponType.freeDelivery:
        return 'Miễn phí giao hàng';
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: voucher.code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã sao chép mã ${voucher.code}'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd/MM/yyyy');
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rlg,
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_offer_outlined,
                  color: BananColors.gold,
                  size: 22,
                ),
                const SizedBox(width: BananSpacing.sm),
                Expanded(
                  child: Text(
                    _discountSummary,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (voucher.label != null && voucher.label!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                voucher.label!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: BananSpacing.sm),
            // Code chip + copy button.
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BananSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BananRadii.rsm,
                    color: theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: theme.dividerTheme.color ?? Colors.black12,
                    ),
                  ),
                  child: Text(
                    voucher.code,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  tooltip: 'Sao chép mã',
                  onPressed: () => _copy(context),
                ),
              ],
            ),
            const SizedBox(height: BananSpacing.xs),
            if (voucher.minSubtotal != null && voucher.minSubtotal! > 0)
              _MetaRow(
                icon: Icons.shopping_bag_outlined,
                text: 'Đơn tối thiểu ${_vnd.format(voucher.minSubtotal)}',
              ),
            _MetaRow(
              icon: Icons.event_outlined,
              text: voucher.usedAt != null
                  ? 'Đã dùng ${df.format(voucher.usedAt!.toLocal())}'
                  : 'HSD ${df.format(voucher.endsAt.toLocal())}',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.outline),
          const SizedBox(width: BananSpacing.xs),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

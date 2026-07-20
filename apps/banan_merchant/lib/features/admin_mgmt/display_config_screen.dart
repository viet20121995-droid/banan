import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/read_only_banner.dart';
import '../../shared/shell/merchant_shell.dart';

/// Admin/merchant-owner config for customer-facing display preferences.
///
/// Today there's only one toggle — whether to surface stock-remaining
/// badges on the customer storefront. It's off by default because the
/// underlying `stockQty` is chain-wide (not per-branch), so "Còn 3 cái"
/// can be confusing when the customer's nearest branch doesn't actually
/// hold any. Merchants flip it on only when stock is genuinely scarce
/// chain-wide (limited drops, seasonal items).
class DisplayConfigScreen extends ConsumerStatefulWidget {
  const DisplayConfigScreen({super.key});

  @override
  ConsumerState<DisplayConfigScreen> createState() =>
      _DisplayConfigScreenState();
}

class _DisplayConfigScreenState
    extends ConsumerState<DisplayConfigScreen> {
  bool _saving = false;

  Future<void> _toggleStock(bool next) async {
    setState(() => _saving = true);
    final res = await ref
        .read(displayConfigApiProvider)
        .update(showStockToCustomers: next);
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ref.invalidate(displayConfigProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next
                  ? 'Đã bật hiển thị tồn kho cho khách hàng.'
                  : 'Đã tắt hiển thị tồn kho.',
            ),
          ),
        );
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authFailureMessage(f))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(displayConfigProvider);
    // GET is @Public but `@Patch()` on DisplayConfigController is
    // @Roles(ADMIN) — this is one chain-wide singleton shown to every
    // customer, so an owner may look but not touch.
    final canEdit =
        ref.watch(authSessionProvider).valueOrNull?.user.role.isAdmin ?? false;

    return MerchantShell(
      title: 'Tuỳ chỉnh hiển thị',
      onRefresh: () async => ref.invalidate(displayConfigProvider),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(displayConfigProvider),
        ),
        data: (cfg) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(BananSpacing.lg),
              children: [
                if (!canEdit)
                  const ReadOnlyBanner(
                    'Bạn xem được cấu hình này nhưng không sửa được. Nó áp '
                    'dụng cho toàn chuỗi và mọi khách hàng, nên chỉ quản trị '
                    'viên (ADMIN) mới đổi được.',
                  ),
                Container(
                  padding: const EdgeInsets.all(BananSpacing.lg),
                  decoration: BoxDecoration(
                    borderRadius: BananRadii.rmd,
                    color: theme.colorScheme.surface,
                    border: Border.all(
                      color: theme.dividerTheme.color ?? Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hiển thị tồn kho cho khách hàng',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: BananSpacing.xs),
                      Text(
                        'Tồn kho được tính chung cho toàn chuỗi (không '
                        'theo từng chi nhánh). Nếu bật, khách sẽ thấy badge '
                        '"Còn N" + "Sắp hết" + "Hết hàng" trên thẻ sản '
                        'phẩm và trang chi tiết. Khuyên dùng cho các đợt '
                        'phát hành giới hạn (bánh sinh nhật, theo mùa). '
                        'Mặc định tắt để tránh hiểu nhầm.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: BananSpacing.md),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: cfg.showStockToCustomers,
                        onChanged:
                            (_saving || !canEdit) ? null : _toggleStock,
                        title: Text(
                          cfg.showStockToCustomers
                              ? 'Đang hiển thị'
                              : 'Đang ẩn',
                          style: theme.textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          cfg.showStockToCustomers
                              ? 'Khách hàng đang thấy các badge tồn kho.'
                              : 'Khách hàng không thấy thông tin tồn kho.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                      if (_saving) ...[
                        const SizedBox(height: BananSpacing.xs),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: BananSpacing.lg),
                _ContactChannelsBlock(initial: cfg, canEdit: canEdit),
                const SizedBox(height: BananSpacing.lg),
                Text(
                  'Lưu ý: chức năng quản lý kho (tự trừ khi đặt, chặn bán '
                  'quá tồn) vẫn hoạt động bình thường dù bật hay tắt mục '
                  'trên. Mục này chỉ thay đổi GIAO DIỆN khách thấy.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontStyle: FontStyle.italic,
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

/// Editor for the 4 contact channels surfaced by the customer "Liên hệ"
/// FAB. Saves the whole bundle at once with one PATCH — clearing a
/// field (empty string) removes that channel from the customer's sheet.
class _ContactChannelsBlock extends ConsumerStatefulWidget {
  const _ContactChannelsBlock({required this.initial, required this.canEdit});
  final DisplayConfig initial;

  /// Same @Roles(ADMIN) PATCH as the toggle above — read-only for everyone else.
  final bool canEdit;

  @override
  ConsumerState<_ContactChannelsBlock> createState() =>
      _ContactChannelsBlockState();
}

class _ContactChannelsBlockState
    extends ConsumerState<_ContactChannelsBlock> {
  late final TextEditingController _phone;
  late final TextEditingController _zalo;
  late final TextEditingController _messenger;
  late final TextEditingController _email;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.initial.contactPhone ?? '');
    _zalo =
        TextEditingController(text: widget.initial.contactZaloOaId ?? '');
    _messenger = TextEditingController(
      text: widget.initial.contactMessengerId ?? '',
    );
    _email = TextEditingController(text: widget.initial.contactEmail ?? '');
  }

  @override
  void dispose() {
    _phone.dispose();
    _zalo.dispose();
    _messenger.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final res = await ref.read(displayConfigApiProvider).update(
          contactPhone: _phone.text.trim(),
          contactZaloOaId: _zalo.text.trim(),
          contactMessengerId: _messenger.text.trim(),
          contactEmail: _email.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ref.invalidate(displayConfigProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu kênh liên hệ.')),
        );
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authFailureMessage(f))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kênh liên hệ trên site khách',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: BananSpacing.xs),
          Text(
            'Mỗi kênh để trống = ẩn khỏi nút "Liên hệ". Khi tất cả đều '
            'trống, nút "Liên hệ" trên site khách cũng tự ẩn.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: BananSpacing.md),
          TextField(
            controller: _zalo,
            enabled: widget.canEdit,
            decoration: const InputDecoration(
              labelText: 'Zalo OA ID',
              hintText: 'vd 4040891234567890',
              prefixIcon: Icon(Icons.chat_bubble_outline),
              helperText:
                  'Lấy từ Zalo Business: zalo.me/<id>. Để trống nếu chưa có.',
            ),
          ),
          const SizedBox(height: BananSpacing.sm),
          TextField(
            controller: _phone,
            enabled: widget.canEdit,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại',
              hintText: '+84867540939',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: BananSpacing.sm),
          TextField(
            controller: _messenger,
            enabled: widget.canEdit,
            decoration: const InputDecoration(
              labelText: 'Facebook Messenger ID',
              hintText: 'username trên facebook.com/<username>',
              prefixIcon: Icon(Icons.facebook),
            ),
          ),
          const SizedBox(height: BananSpacing.sm),
          TextField(
            controller: _email,
            enabled: widget.canEdit,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email hỗ trợ',
              hintText: 'support@banan.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: BananSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: (_saving || !widget.canEdit) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Lưu kênh liên hệ'),
            ),
          ),
        ],
      ),
    );
  }
}

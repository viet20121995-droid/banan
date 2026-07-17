import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/shell/merchant_shell.dart';

/// P4 #37 — compose an in-app campaign notification pushed to every
/// customer's inbox. (No email / FCM — those are separate opt-in channels.)
class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key});
  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _link = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _ok = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gửi thông báo cho tất cả khách?'),
        content: const Text(
          'Thông báo sẽ xuất hiện trong hộp thư của mọi khách hàng. '
          'Không thể thu hồi. Tiếp tục?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Gửi'),),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _msg = null;
      _ok = false;
    });
    final res = await ref.read(merchantToolsApiProvider).broadcast(
          title: _title.text.trim(),
          body: _body.text.trim(),
          linkPath: _link.text.trim(),
        );
    if (!mounted) return;
    res.when(
      success: (n) => setState(() {
        _busy = false;
        _ok = true;
        _msg = 'Đã gửi tới $n khách hàng.';
        _title.clear();
        _body.clear();
        _link.clear();
      }),
      failure: (f) => setState(() {
        _busy = false;
        _msg = f.message ?? f.code;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MerchantShell(
      title: 'Thông báo hàng loạt',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(BananSpacing.lg),
              children: [
                Text('Gửi thông báo trong ứng dụng',
                    style: theme.textTheme.titleLarge,),
                const SizedBox(height: BananSpacing.xs),
                Text(
                  'Thông báo hiển thị trong hộp thư của khách trên web & app. '
                  'Dùng cho khuyến mãi, thông báo nghỉ lễ, sản phẩm mới…',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: BananSpacing.lg),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Tiêu đề *'),
                  maxLength: 120,
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Nhập tiêu đề'
                      : null,
                ),
                TextFormField(
                  controller: _body,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung *',
                    alignLabelWithHint: true,
                  ),
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Nhập nội dung'
                      : null,
                ),
                TextFormField(
                  controller: _link,
                  decoration: const InputDecoration(
                    labelText: 'Đường dẫn khi bấm (tuỳ chọn)',
                    hintText: 'vd: /bundles/combo-bua-sang',
                  ),
                ),
                const SizedBox(height: BananSpacing.md),
                FilledButton.icon(
                  onPressed: _busy ? null : _send,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),)
                      : const Icon(Icons.campaign_outlined),
                  label: Text(_busy ? 'Đang gửi…' : 'Gửi cho tất cả khách'),
                ),
                if (_msg != null) ...[
                  const SizedBox(height: BananSpacing.md),
                  Text(
                    _msg!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: _ok
                          ? BananColors.success
                          : theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

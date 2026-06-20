import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/cover_image_picker.dart';
import '../../shared/shell/merchant_shell.dart';

/// Admin-only screen for the customer-site promotional popup.
class PromoPopupScreen extends ConsumerStatefulWidget {
  const PromoPopupScreen({super.key});

  @override
  ConsumerState<PromoPopupScreen> createState() => _PromoPopupScreenState();
}

class _PromoPopupScreenState extends ConsumerState<PromoPopupScreen> {
  late Future<PromoPopup> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(promoPopupApiProvider).adminGet().then(
          (r) => r.when(
            success: (p) => p,
            failure: (f) => throw Exception(authFailureMessage(f)),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return MerchantShell(
      title: 'Popup quảng cáo',
      onRefresh: () async => setState(_reload),
      body: FutureBuilder<PromoPopup>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return ErrorState(
              message: snap.error?.toString() ?? 'Không tải được cấu hình.',
              onRetry: () => setState(_reload),
            );
          }
          return _Form(
            initial: snap.data!,
            onSaved: () => setState(_reload),
          );
        },
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.initial, required this.onSaved});
  final PromoPopup initial;
  final VoidCallback onSaved;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late TextEditingController _title;
  late TextEditingController _body;
  late TextEditingController _ctaLabel;
  late TextEditingController _ctaUrl;
  late TextEditingController _countdown;
  late bool _isActive;
  String? _imageUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial.title);
    _body = TextEditingController(text: widget.initial.body);
    _ctaLabel = TextEditingController(text: widget.initial.ctaLabel ?? '');
    _ctaUrl = TextEditingController(text: widget.initial.ctaUrl ?? '');
    _countdown = TextEditingController(
      text: widget.initial.countdownSeconds.toString(),
    );
    _isActive = widget.initial.isActive;
    _imageUrl = widget.initial.imageUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _ctaLabel.dispose();
    _ctaUrl.dispose();
    _countdown.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final res = await ref.read(promoPopupApiProvider).adminUpdate(
          isActive: _isActive,
          title: _title.text.trim(),
          body: _body.text,
          imageUrl: _imageUrl ?? '',
          ctaLabel: _ctaLabel.text.trim(),
          ctaUrl: _ctaUrl.text.trim(),
          countdownSeconds:
              int.tryParse(_countdown.text.trim()) ?? 0,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu popup.')),
        );
        widget.onSaved();
      },
      failure: (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authFailureMessage(f))),
        );
      },
    );
  }

  Future<void> _bumpVersion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hiển thị lại cho mọi khách?'),
        content: const Text(
          'Tất cả khách (kể cả những người đã tắt popup trước đó) sẽ thấy '
          'lại popup ở lần truy cập tiếp theo. Phù hợp khi vừa đổi nội dung.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hiển thị lại'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ref.read(promoPopupApiProvider).adminBump();
    if (!mounted) return;
    res.when(
      success: (p) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã bump version → ${p.version}.')),
        );
        widget.onSaved();
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authFailureMessage(f))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(BananSpacing.lg),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Section(
                  title: 'Trạng thái',
                  description:
                      'Bật popup để hiển thị cho mọi khách khi vào trang chủ. '
                      'Mỗi khách chỉ thấy 1 lần cho đến khi admin bấm "Hiển '
                      'thị lại cho mọi khách".',
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    title: Text(
                      _isActive
                          ? 'Popup đang bật'
                          : 'Popup đang tắt',
                      style: theme.textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      'Version hiện tại: ${widget.initial.version}',
                    ),
                  ),
                ),
                _Section(
                  title: 'Nội dung',
                  child: Column(
                    children: [
                      TextField(
                        controller: _title,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Tiêu đề',
                        ),
                      ),
                      const SizedBox(height: BananSpacing.sm),
                      TextField(
                        controller: _body,
                        maxLines: 5,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'Nội dung',
                          helperText:
                              'Có thể nhiều dòng. Hiển thị bên dưới tiêu đề.',
                        ),
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'Ảnh banner (tuỳ chọn)',
                  description:
                      'Tỉ lệ khuyến nghị 16:9, hiển thị ở đầu popup. Bỏ trống '
                      'nếu popup chỉ có chữ.',
                  child: CoverImagePicker(
                    url: _imageUrl,
                    label: 'Ảnh popup',
                    helperText: 'Hiển thị ở đầu popup quảng cáo.',
                    recommendedSize: '1200×900px (tỉ lệ 4:3)',
                    onChanged: (url) => setState(() => _imageUrl = url),
                  ),
                ),
                _Section(
                  title: 'Nút kêu gọi (tuỳ chọn)',
                  description:
                      'Khi khách bấm nút, popup đóng và mở liên kết bạn đặt.',
                  child: Column(
                    children: [
                      TextField(
                        controller: _ctaLabel,
                        maxLength: 40,
                        decoration: const InputDecoration(
                          labelText: 'Nhãn nút',
                          hintText: 'VD: Đặt ngay',
                        ),
                      ),
                      const SizedBox(height: BananSpacing.sm),
                      TextField(
                        controller: _ctaUrl,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Liên kết khi bấm',
                          hintText: 'https://… hoặc /product/<id>',
                        ),
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'Tự đóng',
                  description:
                      'Đếm ngược trước khi popup tự đóng. Đặt 0 để chỉ đóng '
                      'khi khách bấm X.',
                  child: TextField(
                    controller: _countdown,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Đếm ngược (giây)',
                      suffixText: 'giây',
                      helperText: '0–120 giây. 0 = không tự đóng.',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: BananSpacing.md,
                  ),
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Lưu popup'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _bumpVersion,
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Hiển thị lại cho mọi khách'),
                ),
                const SizedBox(height: BananSpacing.huge),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.description,
  });
  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: BananSpacing.lg),
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (description != null) ...[
            const SizedBox(height: BananSpacing.xs),
            Text(description!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: BananSpacing.md),
          child,
        ],
      ),
    );
  }
}

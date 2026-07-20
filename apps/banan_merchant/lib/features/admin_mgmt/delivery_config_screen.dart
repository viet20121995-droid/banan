import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

/// Admin-only screen for editing the delivery-fee config. Pricing layout:
///   - 2 tiers (Standard / Birthday cake collection)
///   - 2 ward bands (Same ward as fulfilling store / Different ward)
///
/// Saving applies immediately to every new order; existing orders keep
/// the fee that was computed at creation time.
class DeliveryConfigScreen extends ConsumerStatefulWidget {
  const DeliveryConfigScreen({super.key});

  @override
  ConsumerState<DeliveryConfigScreen> createState() =>
      _DeliveryConfigScreenState();
}

class _DeliveryConfigScreenState
    extends ConsumerState<DeliveryConfigScreen> {
  late Future<DeliveryConfig> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(geoApiProvider).getConfig().then(
          (r) => r.when(
            success: (c) => c,
            failure: (f) => throw Exception(authFailureMessage(f)),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return MerchantShell(
      title: 'Phí giao hàng',
      onRefresh: () async => setState(_reload),
      body: FutureBuilder<DeliveryConfig>(
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
  final DeliveryConfig initial;
  final VoidCallback onSaved;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late TextEditingController _stdSame;
  late TextEditingController _stdOther;
  late TextEditingController _cakeSame;
  late TextEditingController _cakeOther;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _stdSame = TextEditingController(
      text: widget.initial.standardFeeSameWardVnd.toString(),
    );
    _stdOther = TextEditingController(
      text: widget.initial.standardFeeOtherWardVnd.toString(),
    );
    _cakeSame = TextEditingController(
      text: widget.initial.birthdayCakeFeeSameWardVnd.toString(),
    );
    _cakeOther = TextEditingController(
      text: widget.initial.birthdayCakeFeeOtherWardVnd.toString(),
    );
  }

  @override
  void dispose() {
    _stdSame.dispose();
    _stdOther.dispose();
    _cakeSame.dispose();
    _cakeOther.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final res = await ref.read(geoApiProvider).updateConfig(
          standardFeeSameWardVnd: int.tryParse(_stdSame.text.trim()),
          standardFeeOtherWardVnd: int.tryParse(_stdOther.text.trim()),
          birthdayCakeFeeSameWardVnd:
              int.tryParse(_cakeSame.text.trim()),
          birthdayCakeFeeOtherWardVnd:
              int.tryParse(_cakeOther.text.trim()),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu phí giao hàng.')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

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
                  title: 'Quy tắc tính phí',
                  description:
                      'Phí dựa trên phường khách hàng so với phường của '
                      'cửa hàng nhận đơn. Trùng phường = phí "Cùng phường"; '
                      'khác phường = phí "Phường khác".',
                  child: Text(
                    'Khi đơn có ít nhất 1 sản phẩm thuộc danh mục Bánh sinh '
                    'nhật, áp dụng biểu phí "Bánh sinh nhật" thay vì "Sản '
                    'phẩm thường". Danh mục này được đặt ở mục Danh mục, bật '
                    '"Đây là danh mục Bánh sinh nhật".',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
                _Section(
                  title: 'Sản phẩm thường',
                  description:
                      'Áp dụng cho mọi đơn không có bánh thuộc danh mục Bánh '
                      'sinh nhật. Đặt 0₫ ở mục "Cùng phường" để miễn phí '
                      'giao hàng nội phường.',
                  child: Column(
                    children: [
                      _FeeField(
                        controller: _stdSame,
                        label: 'Cùng phường (khách + cửa hàng cùng phường)',
                        fmt: fmt,
                      ),
                      const SizedBox(height: BananSpacing.sm),
                      _FeeField(
                        controller: _stdOther,
                        label: 'Phường khác',
                        fmt: fmt,
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'Bánh sinh nhật',
                  description:
                      'Bánh sinh nhật cồng kềnh và dễ vỡ nên phí thường cao '
                      'hơn sản phẩm thường ở cả hai mức. Sản phẩm được tính '
                      'là bánh sinh nhật khi thuộc danh mục Bánh sinh nhật '
                      '(đặt ở mục Danh mục).',
                  child: Column(
                    children: [
                      _FeeField(
                        controller: _cakeSame,
                        label: 'Cùng phường',
                        fmt: fmt,
                      ),
                      const SizedBox(height: BananSpacing.sm),
                      _FeeField(
                        controller: _cakeOther,
                        label: 'Phường khác',
                        fmt: fmt,
                      ),
                    ],
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
                    label: const Text('Lưu phí giao hàng'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: BananSpacing.sm),
                  child: Text(
                    'Thay đổi áp dụng ngay cho các đơn mới sau khi lưu. '
                    'Đơn đã đặt vẫn dùng phí lúc đặt.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
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

class _FeeField extends StatelessWidget {
  const _FeeField({
    required this.controller,
    required this.label,
    required this.fmt,
  });
  final TextEditingController controller;
  final String label;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final raw = int.tryParse(controller.text) ?? 0;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        helperText: raw <= 0 ? 'Miễn phí' : fmt.format(raw),
        suffixText: '₫',
      ),
      onChanged: (_) {
        (context as Element).markNeedsBuild();
      },
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

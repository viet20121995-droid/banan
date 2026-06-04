import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

final _couponsProvider =
    FutureProvider.autoDispose<List<MerchantCoupon>>((ref) async {
  final res = await ref.watch(merchantCouponsRepositoryProvider).list();
  return res.when(
    success: (list) => list,
    failure: (f) => throw Exception(authFailureMessage(f)),
  );
});

class CouponsScreen extends ConsumerWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_couponsProvider);
    return MerchantShell(
      title: 'Mã khuyến mãi',
      onRefresh: () async => ref.invalidate(_couponsProvider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tạo mã mới'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_couponsProvider),
        ),
        data: (coupons) {
          if (coupons.isEmpty) {
            return const EmptyState(
              title: 'Chưa có mã khuyến mãi',
              message: 'Tạo mã dùng chung hoặc 1 lần để chạy chương trình.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_couponsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: coupons.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: BananSpacing.sm),
              itemBuilder: (_, i) => _CouponCard(coupon: coupons[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CouponEditorSheet(),
    );
    if (created ?? false) ref.invalidate(_couponsProvider);
  }
}

class _CouponCard extends ConsumerWidget {
  const _CouponCard({required this.coupon});
  final MerchantCoupon coupon;

  String _valueText() {
    switch (coupon.type) {
      case CouponType.percent:
        return 'Giảm ${coupon.value.toStringAsFixed(0)}%';
      case CouponType.fixed:
        return 'Giảm ${NumberFormat.decimalPattern('vi_VN').format(coupon.value)}₫';
      case CouponType.freeDelivery:
        return 'Miễn phí giao hàng';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final df = DateFormat.yMMMd();
    final usage = coupon.maxRedemptions == null
        ? '${coupon.redemptions} lượt dùng · không giới hạn'
        : '${coupon.redemptions}/${coupon.maxRedemptions} lượt dùng';
    final perUser = coupon.perUserLimit == 1
        ? 'mỗi khách 1 lần'
        : '${coupon.perUserLimit} lượt / khách';

    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(
          color: coupon.isActive && !coupon.expired
              ? BananColors.gold
              : theme.dividerTheme.color ?? Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  coupon.code,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: const [],
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (coupon.chainWide)
                _Tag(text: 'Toàn chuỗi', color: theme.colorScheme.outline),
              const SizedBox(width: BananSpacing.xs),
              _Tag(
                text: coupon.expired
                    ? 'Hết hạn'
                    : coupon.isActive
                        ? 'Đang bật'
                        : 'Đã tạm dừng',
                color: coupon.expired
                    ? theme.colorScheme.error
                    : coupon.isActive
                        ? BananColors.success
                        : theme.colorScheme.outline,
              ),
            ],
          ),
          if (coupon.label != null && coupon.label!.isNotEmpty)
            Text(coupon.label!, style: theme.textTheme.bodySmall),
          const SizedBox(height: BananSpacing.xs),
          Text(_valueText(), style: theme.textTheme.titleSmall),
          const SizedBox(height: BananSpacing.xs),
          Text(
            '$usage · $perUser',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            '${df.format(coupon.startsAt.toLocal())} → '
            '${df.format(coupon.endsAt.toLocal())}'
            '${coupon.minSubtotalVnd != null ? ' · tối thiểu ${NumberFormat.decimalPattern('vi_VN').format(coupon.minSubtotalVnd)}₫' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          if (coupon.editable) ...[
            const Divider(height: BananSpacing.lg),
            Row(
              children: [
                const Text('Đang bật'),
                const Spacer(),
                Switch(
                  value: coupon.isActive,
                  onChanged: (v) async {
                    final res = await ref
                        .read(merchantCouponsRepositoryProvider)
                        .update(coupon.id, isActive: v);
                    res.when(
                      success: (_) => ref.invalidate(_couponsProvider),
                      failure: (f) =>
                          ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(authFailureMessage(f))),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600,),
      ),
    );
  }
}

class _CouponEditorSheet extends ConsumerStatefulWidget {
  const _CouponEditorSheet();

  @override
  ConsumerState<_CouponEditorSheet> createState() =>
      _CouponEditorSheetState();
}

class _CouponEditorSheetState extends ConsumerState<_CouponEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _minSubtotal = TextEditingController();
  final _maxRedemptions = TextEditingController();
  final _perUser = TextEditingController(text: '1');
  final _label = TextEditingController();
  CouponType _type = CouponType.percent;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _minSubtotal.dispose();
    _maxRedemptions.dispose();
    _perUser.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'End date must be after the start date.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = CouponDraft(
      code: _code.text.trim().toUpperCase(),
      type: _type,
      value: _type == CouponType.freeDelivery
          ? 1
          : int.tryParse(_value.text.trim()) ?? 0,
      minSubtotalVnd: int.tryParse(_minSubtotal.text.trim()),
      startsAt: _start,
      endsAt: _end,
      maxRedemptions: int.tryParse(_maxRedemptions.text.trim()),
      perUserLimit: int.tryParse(_perUser.text.trim()) ?? 1,
      label: _label.text.trim().isEmpty ? null : _label.text.trim(),
    );
    final res =
        await ref.read(merchantCouponsRepositoryProvider).create(draft);
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) => Navigator.pop(context, true),
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat.yMMMd();
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          BananSpacing.lg, 0, BananSpacing.lg, bottom + BananSpacing.lg,),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('Tạo mã khuyến mãi', style: theme.textTheme.titleLarge),
            const SizedBox(height: BananSpacing.md),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(BananSpacing.md),
                margin: const EdgeInsets.only(bottom: BananSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BananRadii.rmd,
                  color: theme.colorScheme.errorContainer
                      .withValues(alpha: 0.4),
                ),
                child: Text(_error!),
              ),
            TextFormField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Mã',
                hintText: 'SUMMER25',
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'Tối thiểu 3 ký tự' : null,
            ),
            const SizedBox(height: BananSpacing.sm),
            DropdownButtonFormField<CouponType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Loại giảm giá'),
              items: const [
                DropdownMenuItem(
                  value: CouponType.percent,
                  child: Text('Giảm theo % '),
                ),
                DropdownMenuItem(
                  value: CouponType.fixed,
                  child: Text('Giảm tiền cố định (₫)'),
                ),
                DropdownMenuItem(
                  value: CouponType.freeDelivery,
                  child: Text('Miễn phí giao hàng'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _type = v ?? CouponType.percent),
            ),
            if (_type != CouponType.freeDelivery) ...[
              const SizedBox(height: BananSpacing.sm),
              TextFormField(
                controller: _value,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _type == CouponType.percent
                      ? 'Phần trăm (1–100)'
                      : 'Số tiền giảm (₫)',
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Nhập một số';
                  if (_type == CouponType.percent && n > 100) {
                    return 'Tối đa 100%';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: BananSpacing.sm),
            TextFormField(
              controller: _minSubtotal,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tổng tối thiểu ₫ (tuỳ chọn)',
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(true),
                    child: Text('Từ: ${df.format(_start)}'),
                  ),
                ),
                const SizedBox(width: BananSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(false),
                    child: Text('Đến: ${df.format(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BananSpacing.sm),
            TextFormField(
              controller: _maxRedemptions,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tổng lượt dùng (trống = không giới hạn)',
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            TextFormField(
              controller: _perUser,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Lượt dùng / khách (1 = mỗi khách 1 lần)',
              ),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                return (n == null || n < 1) ? 'Tối thiểu 1' : null;
              },
            ),
            const SizedBox(height: BananSpacing.sm),
            TextFormField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Nhãn nội bộ (tuỳ chọn)',
              ),
            ),
            const SizedBox(height: BananSpacing.lg),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Tạo mã'),
            ),
          ],
        ),
      ),
    );
  }
}

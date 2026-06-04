import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final _customerDetailProvider = FutureProvider.autoDispose
    .family<CustomerDetail, String>((ref, id) async {
  final res = await ref.watch(customersRepositoryProvider).detail(id);
  return res.when(
    success: (d) => d,
    failure: (f) => throw Exception(authFailureMessage(f)),
  );
});

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({required this.customerId, super.key});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_customerDetailProvider(customerId));
    return AppScaffold(
      appBar: AppBar(title: const Text('Khách hàng')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(_customerDetailProvider(customerId)),
        ),
        data: (c) => _Detail(customer: c),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.customer});
  final CustomerDetail customer;

  void _refresh(WidgetRef ref) =>
      ref.invalidate(_customerDetailProvider(customer.id));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat.yMMMd();

    return ListView(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: BananColors.gold,
              backgroundImage: (customer.avatarUrl != null &&
                      customer.avatarUrl!.isNotEmpty)
                  ? NetworkImage(customer.avatarUrl!)
                  : null,
              child: (customer.avatarUrl == null ||
                      customer.avatarUrl!.isEmpty)
                  ? Text(
                      customer.fullName.isEmpty
                          ? '?'
                          : customer.fullName[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22,),
                    )
                  : null,
            ),
            const SizedBox(width: BananSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.fullName,
                      style: theme.textTheme.titleLarge,),
                  Text(
                    '${customer.membershipTier.name.toUpperCase()} · '
                    '${customer.pointsBalance} Micho',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: BananSpacing.md),
        // ── Interaction actions ──
        Wrap(
          spacing: BananSpacing.sm,
          runSpacing: BananSpacing.sm,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _sendMessage(context, ref),
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('Gửi tin nhắn'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _adjustPoints(context, ref),
              icon: const Icon(Icons.stars_outlined, size: 18),
              label: const Text('Điều chỉnh Micho'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _sendCoupon(context, ref),
              icon: const Icon(Icons.card_giftcard_outlined, size: 18),
              label: const Text('Tặng mã giảm giá'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _editNotes(context, ref),
              icon: const Icon(Icons.edit_note_outlined, size: 18),
              label: const Text('Ghi chú & nhãn'),
            ),
          ],
        ),
        const SizedBox(height: BananSpacing.lg),
        _Section(
          title: 'Liên hệ',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv(theme, Icons.email_outlined, customer.email),
              if (customer.phone != null)
                _kv(theme, Icons.phone_outlined, customer.phone!),
              if (customer.birthday != null)
                _kv(theme, Icons.cake_outlined,
                    dateFmt.format(customer.birthday!),),
              _kv(theme, Icons.event_outlined,
                  'Thành viên từ ${dateFmt.format(customer.memberSince)}',),
            ],
          ),
        ),
        const SizedBox(height: BananSpacing.md),
        if (customer.tags.isNotEmpty || customer.notes != null) ...[
          _Section(
            title: 'CRM nội bộ (riêng tư)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (customer.tags.isNotEmpty)
                  Wrap(
                    spacing: BananSpacing.xs,
                    runSpacing: BananSpacing.xs,
                    children: [
                      for (final t in customer.tags)
                        Chip(
                          label: Text(t),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                if (customer.notes != null &&
                    customer.notes!.isNotEmpty) ...[
                  const SizedBox(height: BananSpacing.sm),
                  Text(customer.notes!,
                      style: theme.textTheme.bodyMedium,),
                ],
              ],
            ),
          ),
          const SizedBox(height: BananSpacing.md),
        ],
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Đơn hàng',
                value: '${customer.orderCount}',
              ),
            ),
            const SizedBox(width: BananSpacing.md),
            Expanded(
              child: _Stat(
                label: 'Tổng chi tiêu',
                value: money.format(customer.totalSpentVnd),
              ),
            ),
          ],
        ),
        const SizedBox(height: BananSpacing.md),
        _Section(
          title: 'Địa chỉ',
          child: customer.addresses.isEmpty
              ? Text('Chưa có địa chỉ đã lưu',
                  style: theme.textTheme.bodyMedium,)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in customer.addresses)
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: BananSpacing.sm,),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(a.label,
                                    style: theme.textTheme.titleSmall,),
                                if (a.isDefault) ...[
                                  const SizedBox(width: BananSpacing.xs),
                                  Text('(mặc định)',
                                      style: theme.textTheme.labelSmall,),
                                ],
                              ],
                            ),
                            Text('${a.recipient} · ${a.phone}',
                                style: theme.textTheme.bodySmall,),
                            Text(a.oneLine,
                                style: theme.textTheme.bodyMedium,),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: BananSpacing.md),
        _Section(
          title: 'Đơn hàng gần đây',
          child: customer.orders.isEmpty
              ? Text('Chưa có đơn hàng', style: theme.textTheme.bodyMedium)
              : Column(
                  children: [
                    for (final o in customer.orders)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(o.code),
                        subtitle: Text(
                          '${o.status} · ${o.fulfillmentType} · '
                          '${dateFmt.format(o.createdAt.toLocal())}',
                        ),
                        trailing: Text(
                          money.format(o.totalVnd),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  // ───────────────────────── Action dialogs ─────────────────────────

  Future<void> _sendMessage(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gửi tin nhắn'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Tiêu đề'),
              ),
              TextField(
                controller: bodyCtrl,
                maxLength: 1000,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Nội dung'),
              ),
            ],
          ),
        ),
        actions: _dialogActions(ctx),
      ),
    );
    if (ok != true) return;
    if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) {
      _snack(ref, 'Tiêu đề và nội dung là bắt buộc.');
      return;
    }
    final res = await ref.read(customersRepositoryProvider).notify(
          customerId: customer.id,
          title: titleCtrl.text.trim(),
          body: bodyCtrl.text.trim(),
        );
    res.when(
      success: (_) => _snack(ref, 'Đã gửi tin tới ${customer.fullName}.'),
      failure: (f) => _snack(ref, authFailureMessage(f)),
    );
  }

  Future<void> _adjustPoints(BuildContext context, WidgetRef ref) async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    var sign = 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Điều chỉnh Micho'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Cộng')),
                    ButtonSegment(value: -1, label: Text('Trừ')),
                  ],
                  selected: {sign},
                  onSelectionChanged: (s) =>
                      setSt(() => sign = s.first),
                ),
                const SizedBox(height: BananSpacing.sm),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Số Micho',),
                ),
                TextField(
                  controller: reasonCtrl,
                  maxLength: 200,
                  decoration:
                      const InputDecoration(labelText: 'Lý do'),
                ),
              ],
            ),
          ),
          actions: _dialogActions(ctx),
        ),
      ),
    );
    if (ok != true) return;
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0 || reasonCtrl.text.trim().isEmpty) {
      _snack(ref, 'Nhập số dương và lý do.');
      return;
    }
    final res = await ref.read(customersRepositoryProvider).adjustPoints(
          customerId: customer.id,
          delta: sign * amount,
          reason: reasonCtrl.text.trim(),
        );
    res.when(
      success: (balance) {
        _snack(ref, 'Đã cập nhật. Số dư mới: $balance Micho.');
        _refresh(ref);
      },
      failure: (f) => _snack(ref, authFailureMessage(f)),
    );
  }

  Future<void> _sendCoupon(BuildContext context, WidgetRef ref) async {
    final valueCtrl = TextEditingController();
    final minCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '30');
    var type = GiftCouponType.percent;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Tặng mã giảm giá'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<GiftCouponType>(
                  initialValue: type,
                  decoration:
                      const InputDecoration(labelText: 'Loại'),
                  items: const [
                    DropdownMenuItem(
                      value: GiftCouponType.percent,
                      child: Text('Giảm theo % '),
                    ),
                    DropdownMenuItem(
                      value: GiftCouponType.fixed,
                      child: Text('Giảm tiền cố định (₫)'),
                    ),
                    DropdownMenuItem(
                      value: GiftCouponType.freeDelivery,
                      child: Text('Miễn phí giao hàng'),
                    ),
                  ],
                  onChanged: (v) =>
                      setSt(() => type = v ?? GiftCouponType.percent),
                ),
                if (type != GiftCouponType.freeDelivery)
                  TextField(
                    controller: valueCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: type == GiftCouponType.percent
                          ? 'Phần trăm (1–100)'
                          : 'Số tiền giảm (₫)',
                    ),
                  ),
                TextField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Đơn tối thiểu ₫ (tuỳ chọn)',),
                ),
                TextField(
                  controller: daysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Hiệu lực (số ngày)',),
                ),
              ],
            ),
          ),
          actions: _dialogActions(ctx),
        ),
      ),
    );
    if (ok != true) return;
    final isFree = type == GiftCouponType.freeDelivery;
    final value = isFree ? 1 : (int.tryParse(valueCtrl.text.trim()) ?? 0);
    final days = int.tryParse(daysCtrl.text.trim()) ?? 0;
    if ((!isFree && value <= 0) || days <= 0) {
      _snack(ref, 'Nhập giá trị và số ngày hợp lệ.');
      return;
    }
    final res = await ref.read(customersRepositoryProvider).issueCoupon(
          customerId: customer.id,
          type: type,
          value: value,
          minSubtotalVnd: int.tryParse(minCtrl.text.trim()),
          days: days,
        );
    res.when(
      success: (code) =>
          _snack(ref, 'Đã tặng mã $code cho ${customer.fullName}.'),
      failure: (f) => _snack(ref, authFailureMessage(f)),
    );
  }

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final notesCtrl = TextEditingController(text: customer.notes ?? '');
    final tagsCtrl =
        TextEditingController(text: customer.tags.join(', '));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ghi chú & nhãn'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tagsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nhãn (phân cách bằng dấu phẩy)',
                  hintText: 'VIP, dị ứng đậu phộng',
                ),
              ),
              const SizedBox(height: BananSpacing.sm),
              TextField(
                controller: notesCtrl,
                maxLines: 5,
                maxLength: 4000,
                decoration:
                    const InputDecoration(labelText: 'Ghi chú nội bộ'),
              ),
            ],
          ),
        ),
        actions: _dialogActions(ctx),
      ),
    );
    if (ok != true) return;
    final tags = tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final res = await ref.read(customersRepositoryProvider).updateNotes(
          customerId: customer.id,
          notes: notesCtrl.text.trim(),
          tags: tags,
        );
    res.when(
      success: (_) {
        _snack(ref, 'Đã lưu.');
        _refresh(ref);
      },
      failure: (f) => _snack(ref, authFailureMessage(f)),
    );
  }

  List<Widget> _dialogActions(BuildContext ctx) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Xác nhận'),
        ),
      ];

  void _snack(WidgetRef ref, String msg) {
    final ctx = ref.context;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _kv(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: BananSpacing.sm),
          Expanded(
              child: Text(text, style: theme.textTheme.bodyMedium),),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border:
            Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: BananSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border:
            Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: BananSpacing.xs),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}

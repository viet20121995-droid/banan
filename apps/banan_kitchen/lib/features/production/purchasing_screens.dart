import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'production_providers.dart';

final _fmt = NumberFormat.decimalPattern('vi_VN');
String _money(num v) => '${_fmt.format(v)} đ';
String _date(DateTime? d) => d == null ? '—' : DateFormat('dd/MM/yyyy').format(d.toLocal());

const _stateLabels = <String, String>{
  'DRAFT': 'Nháp',
  'CONFIRMED': 'Đã xác nhận',
  'PARTIAL': 'Nhận một phần',
  'RECEIVED': 'Đã nhận đủ',
  'CANCELLED': 'Đã huỷ',
};

Color _stateColor(BuildContext context, String state) => switch (state) {
      'CONFIRMED' => BananColors.info,
      'PARTIAL' => BananColors.warning,
      'RECEIVED' => BananColors.success,
      'CANCELLED' => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.outline,
    };

Widget _stateChip(BuildContext context, String state) {
  final color = _stateColor(context, state);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      _stateLabels[state] ?? state,
      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
    ),
  );
}

// ── Suppliers ───────────────────────────────────────────────────────────────

/// Danh bạ nhà cung cấp — tra cứu + thêm/sửa. Ngừng hợp tác = ẩn khỏi form PO.
class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(allSuppliersProvider);
    final canWrite = ref.watch(canProduceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nhà cung cấp')),
      floatingActionButton: !canWrite
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Thêm NCC'),
              onPressed: () => _SupplierSheet.show(context, ref, null),
            ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(allSuppliersProvider.future),
        child: suppliers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(BananSpacing.lg),
            children: [
              Text(
                'Lỗi: $e',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  EmptyState(
                    title: 'Chưa có nhà cung cấp',
                    message: 'Thêm nhà cung cấp đầu tiên để tạo đơn mua.',
                    icon: Icons.storefront_outlined,
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(BananSpacing.lg),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = list[i];
                final sub = [
                  if (s.phone.isNotEmpty) s.phone,
                  if (s.email.isNotEmpty) s.email,
                ].join(' · ');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.storefront_outlined,
                    color: s.active
                        ? BananColors.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  title: Text(
                    s.name,
                    style: s.active
                        ? null
                        : TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                  ),
                  subtitle: sub.isEmpty ? null : Text(sub),
                  trailing: !s.active
                      ? const Text('Ngừng hợp tác',
                          style: TextStyle(fontSize: 12))
                      : (canWrite
                          ? const Icon(Icons.edit_outlined, size: 20)
                          : null),
                  onTap: canWrite
                      ? () => _SupplierSheet.show(context, ref, s)
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SupplierSheet extends ConsumerStatefulWidget {
  const _SupplierSheet({this.existing});

  final MfgSupplier? existing;

  static void show(BuildContext context, WidgetRef ref, MfgSupplier? s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SupplierSheet(existing: s),
    );
  }

  @override
  ConsumerState<_SupplierSheet> createState() => _SupplierSheetState();
}

class _SupplierSheetState extends ConsumerState<_SupplierSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _address =
      TextEditingController(text: widget.existing?.address ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late bool _active = widget.existing?.active ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập tên nhà cung cấp.')),
      );
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(manufacturingApiProvider);
    final res = widget.existing == null
        ? await api.createSupplier(
            name: name,
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            address: _address.text.trim(),
            note: _note.text.trim(),
          )
        : await api.updateSupplier(
            widget.existing!.id,
            name: name,
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            address: _address.text.trim(),
            note: _note.text.trim(),
            active: _active,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ref.invalidate(allSuppliersProvider);
        ref.invalidate(suppliersProvider);
        Navigator.of(context).pop();
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${f.message ?? f.code}')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: BananSpacing.lg,
        right: BananSpacing.lg,
        top: BananSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + BananSpacing.lg,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            widget.existing == null
                ? 'Thêm nhà cung cấp'
                : 'Sửa nhà cung cấp',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: BananSpacing.md),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Tên *'),
          ),
          const SizedBox(height: BananSpacing.sm),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Điện thoại'),
          ),
          const SizedBox(height: BananSpacing.sm),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: BananSpacing.sm),
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Địa chỉ'),
          ),
          const SizedBox(height: BananSpacing.sm),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
          if (widget.existing != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Đang hợp tác'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          const SizedBox(height: BananSpacing.md),
          PrimaryButton(
            label: 'Lưu',
            loading: _saving,
            expand: true,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// ── Purchase order list ─────────────────────────────────────────────────────

class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  ConsumerState<PurchaseOrdersScreen> createState() =>
      _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen> {
  String? _state;

  @override
  Widget build(BuildContext context) {
    final pos = ref.watch(poListProvider(_state));
    final canWrite = ref.watch(canProduceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn mua hàng')),
      floatingActionButton: !canWrite
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Tạo đơn mua'),
              onPressed: () =>
                  context.push('/production/purchase-orders/new'),
            ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: BananSpacing.lg,
              vertical: BananSpacing.sm,
            ),
            child: Row(
              children: [
                for (final entry in [
                  const MapEntry<String?, String>(null, 'Tất cả'),
                  ..._stateLabels.entries,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: BananSpacing.xs),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _state == entry.key,
                      onSelected: (_) => setState(() => _state = entry.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(poListProvider(_state).future),
              child: pos.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(BananSpacing.lg),
                  children: [
                    Text(
                      'Lỗi: $e',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        EmptyState(
                          title: 'Chưa có đơn mua',
                          message:
                              'Tạo đơn mua để theo dõi hàng đặt từ nhà cung cấp.',
                          icon: Icons.receipt_long_outlined,
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(BananSpacing.lg),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final po = list[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Text(
                              po.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: BananSpacing.sm),
                            _stateChip(context, po.state),
                          ],
                        ),
                        subtitle: Text(
                          '${po.supplierName} · ${po.lines.length} dòng · hẹn ${_date(po.expectedDate)}',
                        ),
                        trailing: Text(
                          _money(po.total),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () => context
                            .push('/production/purchase-orders/${po.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Purchase order create ───────────────────────────────────────────────────

class _PoLineDraft {
  MfgProduct? product;
  final qty = TextEditingController();
  final price = TextEditingController();

  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

class PoFormScreen extends ConsumerStatefulWidget {
  const PoFormScreen({super.key});

  @override
  ConsumerState<PoFormScreen> createState() => _PoFormScreenState();
}

class _PoFormScreenState extends ConsumerState<PoFormScreen> {
  String? _supplierId;
  DateTime? _expected;
  final _note = TextEditingController();
  final List<_PoLineDraft> _lines = [_PoLineDraft()];
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final lines = <({String productId, double qty, double unitPrice})>[];
    for (final l in _lines) {
      final qty = double.tryParse(l.qty.text.trim());
      final price = double.tryParse(l.price.text.trim());
      if (l.product == null || qty == null || qty <= 0 || price == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Mỗi dòng cần sản phẩm, số lượng > 0 và đơn giá.'),
          ),
        );
        return;
      }
      lines.add(
        (productId: l.product!.id, qty: qty, unitPrice: price),
      );
    }
    if (_supplierId == null || lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn nhà cung cấp và thêm dòng hàng.')),
      );
      return;
    }
    setState(() => _saving = true);
    final res = await ref.read(manufacturingApiProvider).createPurchaseOrder(
          supplierId: _supplierId!,
          expectedDate: _expected,
          note: _note.text.trim(),
          lines: lines,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (po) {
        ref.invalidate(poListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tạo ${po.code} (nháp).')),
        );
        context.pop();
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${f.message ?? f.code}')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider);
    // Purchases cover the same catalogue as goods receipts: raw + packaging.
    final raw = ref.watch(productsProvider('RAW'));
    final pkg = ref.watch(productsProvider('PACKAGING'));
    final products = [
      ...(raw.valueOrNull ?? const <MfgProduct>[]),
      ...(pkg.valueOrNull ?? const <MfgProduct>[]),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo đơn mua')),
      body: ListView(
        padding: const EdgeInsets.all(BananSpacing.lg),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _supplierId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nhà cung cấp'),
            items: [
              for (final s in suppliers.valueOrNull ?? const <MfgSupplier>[])
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _supplierId = v),
          ),
          const SizedBox(height: BananSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text('Ngày hẹn giao: ${_date(_expected)}'),
            trailing: const Icon(Icons.edit_calendar_outlined, size: 20),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _expected ?? now.add(const Duration(days: 2)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _expected = picked);
            },
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
          const SizedBox(height: BananSpacing.lg),
          Text('Dòng hàng', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: BananSpacing.sm),
          for (var i = 0; i < _lines.length; i++) ...[
            Container(
              padding: const EdgeInsets.all(BananSpacing.md),
              margin: const EdgeInsets.only(bottom: BananSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: BananRadii.rmd,
                border: Border.all(
                  color: Theme.of(context).dividerTheme.color ?? Colors.black12,
                ),
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _lines[i].product?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Nguyên liệu / bao bì',
                    ),
                    items: [
                      for (final p in products)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.nameVi} (${p.code})'),
                        ),
                    ],
                    onChanged: (v) {
                      final matches = products.where((e) => e.id == v);
                      final p = matches.isEmpty ? null : matches.first;
                      setState(() {
                        _lines[i].product = p;
                        // Prefill with the running average cost as a sane start.
                        if (p != null && _lines[i].price.text.isEmpty) {
                          _lines[i].price.text = p.avgCost == 0
                              ? ''
                              : p.avgCost.toStringAsFixed(0);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: BananSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lines[i].qty,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Số lượng',
                            suffixText: _lines[i].product?.uomCode ?? '',
                          ),
                        ),
                      ),
                      const SizedBox(width: BananSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _lines[i].price,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Đơn giá',
                            suffixText: 'đ',
                          ),
                        ),
                      ),
                      if (_lines.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() {
                            _lines.removeAt(i).dispose();
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Thêm dòng'),
            onPressed: () => setState(() => _lines.add(_PoLineDraft())),
          ),
          const SizedBox(height: BananSpacing.xl),
          PrimaryButton(
            label: 'Tạo đơn (nháp)',
            icon: Icons.receipt_long_outlined,
            loading: _saving,
            expand: true,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// ── Purchase order detail ───────────────────────────────────────────────────

class PoDetailScreen extends ConsumerWidget {
  const PoDetailScreen({required this.id, super.key});

  final String id;

  Future<void> _action(
    BuildContext context,
    WidgetRef ref,
    Future<Result<void, AppFailure>> Function() call,
    String okMessage,
  ) async {
    final res = await call();
    if (!context.mounted) return;
    res.when(
      success: (_) {
        ref.invalidate(poDetailProvider(id));
        ref.invalidate(poListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(okMessage)),
        );
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${f.message ?? f.code}')),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final po = ref.watch(poDetailProvider(id));
    final canWrite = ref.watch(canProduceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn mua')),
      body: po.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Lỗi: $e',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        data: (p) {
          final open = p.state == 'CONFIRMED' || p.state == 'PARTIAL';
          return ListView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            children: [
              Row(
                children: [
                  Text(p.code, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: BananSpacing.sm),
                  _stateChip(context, p.state),
                ],
              ),
              const SizedBox(height: BananSpacing.xs),
              Text('Nhà cung cấp: ${p.supplierName}'),
              Text('Ngày hẹn giao: ${_date(p.expectedDate)}'),
              if (p.note.isNotEmpty) Text('Ghi chú: ${p.note}'),
              Text(
                'Tổng: ${_money(p.total)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: BananSpacing.lg),
              Text('Dòng hàng', style: Theme.of(context).textTheme.titleMedium),
              for (final l in p.lines)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${l.productName} (${l.productCode})'),
                  subtitle: Text(
                    'Đã nhận ${_fmt.format(l.qtyReceived)} / ${_fmt.format(l.qty)} ${l.uomCode} · ${_money(l.unitPrice)}/${l.uomCode}',
                  ),
                  trailing: canWrite && open && l.remaining > 0
                      ? TextButton(
                          onPressed: () =>
                              _ReceiveLineDialog.show(context, ref, id, l),
                          child: const Text('Nhận hàng'),
                        )
                      : (l.remaining <= 0
                          ? const Icon(
                              Icons.check_circle_outline,
                              color: BananColors.success,
                              size: 20,
                            )
                          : null),
                ),
              const SizedBox(height: BananSpacing.xl),
              if (canWrite && p.state == 'DRAFT') ...[
                PrimaryButton(
                  label: 'Xác nhận đơn',
                  icon: Icons.check,
                  expand: true,
                  onPressed: () => _action(
                    context,
                    ref,
                    () => ref
                        .read(manufacturingApiProvider)
                        .confirmPurchaseOrder(id),
                    'Đã xác nhận đơn mua.',
                  ),
                ),
                const SizedBox(height: BananSpacing.sm),
              ],
              if (canWrite && (p.state == 'DRAFT' || open))
                OutlinedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Huỷ đơn'),
                  onPressed: () async {
                    final sure = await showDialog<bool>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        title: const Text('Huỷ đơn mua?'),
                        content: const Text(
                          'Hàng đã nhận vẫn nằm trong kho; phần còn lại sẽ đóng.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dctx, false),
                            child: const Text('Không'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dctx, true),
                            child: const Text('Huỷ đơn'),
                          ),
                        ],
                      ),
                    );
                    if (sure != true || !context.mounted) return;
                    await _action(
                      context,
                      ref,
                      () => ref
                          .read(manufacturingApiProvider)
                          .cancelPurchaseOrder(id),
                      'Đã huỷ đơn mua.',
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReceiveLineDialog extends ConsumerStatefulWidget {
  const _ReceiveLineDialog({required this.poId, required this.line});

  final String poId;
  final MfgPoLine line;

  static void show(
    BuildContext context,
    WidgetRef ref,
    String poId,
    MfgPoLine line,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _ReceiveLineDialog(poId: poId, line: line),
    );
  }

  @override
  ConsumerState<_ReceiveLineDialog> createState() =>
      _ReceiveLineDialogState();
}

class _ReceiveLineDialogState extends ConsumerState<_ReceiveLineDialog> {
  late final _qty = TextEditingController(
    text: widget.line.remaining.toStringAsFixed(
      widget.line.remaining == widget.line.remaining.roundToDouble() ? 0 : 3,
    ),
  );
  late final _cost = TextEditingController(
    text: widget.line.unitPrice.toStringAsFixed(0),
  );
  final _lot = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    _cost.dispose();
    _lot.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qty.text.trim());
    final cost = double.tryParse(_cost.text.trim());
    if (qty == null || qty <= 0 || cost == null || cost < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập số lượng > 0 và đơn giá.')),
      );
      return;
    }
    setState(() => _saving = true);
    final res = await ref.read(manufacturingApiProvider).receive(
          productId: widget.line.productId,
          qty: qty,
          unitCost: cost,
          lotName: _lot.text.trim().isEmpty ? null : _lot.text.trim(),
          poLineId: widget.line.id,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ref.invalidate(poDetailProvider(widget.poId));
        ref.invalidate(poListProvider);
        ref.invalidate(onHandProvider);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã nhập kho theo đơn mua.')),
        );
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${f.message ?? f.code}')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    return AlertDialog(
      title: Text('Nhận: ${l.productName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'Số lượng',
              suffixText: l.uomCode,
              helperText:
                  'Còn thiếu ${_fmt.format(l.remaining)} ${l.uomCode}',
            ),
          ),
          const SizedBox(height: BananSpacing.sm),
          TextField(
            controller: _cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Đơn giá thực tế',
              suffixText: 'đ / đơn vị',
            ),
          ),
          const SizedBox(height: BananSpacing.sm),
          TextField(
            controller: _lot,
            decoration: const InputDecoration(
              labelText: 'Tên lô (nếu có)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        TextButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Nhập kho'),
        ),
      ],
    );
  }
}

// ── Purchase history per product ────────────────────────────────────────────

class PurchaseHistoryScreen extends ConsumerWidget {
  const PurchaseHistoryScreen({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(purchaseHistoryProvider(productId));
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử mua')),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(purchaseHistoryProvider(productId).future),
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(BananSpacing.lg),
            children: [
              Text(
                'Lỗi: $e',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  EmptyState(
                    title: 'Chưa có lần nhập nào',
                    message:
                        'Các lần nhập kho của nguyên liệu này sẽ hiển thị tại đây.',
                    icon: Icons.history_outlined,
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(BananSpacing.lg),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = rows[i];
                final source = r.supplierName == null
                    ? 'Nhập lẻ (không qua đơn mua)'
                    : '${r.supplierName} · ${r.poCode}';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${_fmt.format(r.qty)} ${r.uomCode} · ${_money(r.unitCost)}/${r.uomCode}',
                  ),
                  subtitle: Text(
                    '$source${r.lotName == null ? '' : ' · lô ${r.lotName}'}',
                  ),
                  trailing: Text(
                    _date(r.date),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'production_providers.dart';

const mfgStateLabels = {
  'DRAFT': 'Nháp',
  'CONFIRMED': 'Đã xác nhận',
  'PROGRESS': 'Đang làm',
  'DONE': 'Hoàn tất',
  'CANCEL': 'Đã huỷ',
};

Color mfgStateColor(String state) => switch (state) {
      'DONE' => BananColors.success,
      'PROGRESS' => BananColors.gold,
      'CANCEL' => BananColors.cocoaSoft,
      _ => BananColors.info,
    };

/// Manufacturing-order list. [state] pre-filters (from the dashboard cards).
class MoListScreen extends ConsumerWidget {
  const MoListScreen({this.state, super.key});
  final String? state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(moListProvider(state));
    final canProduce = ref.watch(canProduceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state == null
              ? 'Lệnh sản xuất'
              : 'Lệnh · ${mfgStateLabels[state] ?? state}',
        ),
      ),
      floatingActionButton: canProduce
          ? FloatingActionButton.extended(
              onPressed: () => _createDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Tạo lệnh'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(moListProvider(state)),
        child: orders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Lỗi: $e')),
          data: (rows) => rows.isEmpty
              ? const Center(child: Text('Chưa có lệnh sản xuất nào.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(BananSpacing.md),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: BananSpacing.sm),
                  itemBuilder: (context, i) => _MoTile(order: rows[i]),
                ),
        ),
      ),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateMoDialog(),
    );
    if (created != null && context.mounted) {
      ref.invalidate(moListProvider(state));
      unawaited(context.push('/production/orders/$created'));
    }
  }
}

class _MoTile extends StatelessWidget {
  const _MoTile({required this.order});
  final MfgOrderSummary order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: ListTile(
        title: Text('${order.code} · ${order.productNameVi}'),
        subtitle: Text(
          'SL: ${order.qtyToProduce.toStringAsFixed(0)} · ${order.componentCount} thành phần',
        ),
        trailing: _StateChip(state: order.state),
        onTap: () => context.push('/production/orders/${order.id}'),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});
  final String state;
  @override
  Widget build(BuildContext context) {
    final c = mfgStateColor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BananRadii.rPill,
      ),
      child: Text(
        mfgStateLabels[state] ?? state,
        style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

/// Pick a BoM and quantity → creates a draft MO. Returns the new MO id.
class _CreateMoDialog extends ConsumerStatefulWidget {
  const _CreateMoDialog();
  @override
  ConsumerState<_CreateMoDialog> createState() => _CreateMoDialogState();
}

class _CreateMoDialogState extends ConsumerState<_CreateMoDialog> {
  String? _bomId;
  final _qty = TextEditingController(text: '1000');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qty.text.trim());
    if (_bomId == null || qty == null || qty <= 0) {
      setState(() => _error = 'Chọn công thức và nhập số lượng hợp lệ.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await ref
        .read(manufacturingApiProvider)
        .createOrder(bomId: _bomId!, qtyToProduce: qty);
    if (!mounted) return;
    res.when(
      success: (mo) => Navigator.pop(context, mo.id),
      failure: (f) => setState(() {
        _busy = false;
        _error = f.message ?? f.code;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boms = ref.watch(bomListProvider);
    return AlertDialog(
      title: const Text('Tạo lệnh sản xuất'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            boms.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Không tải được công thức: $e'),
              data: (list) => list.isEmpty
                  ? Text(
                      'Chưa có công thức nào — tạo BoM trước.',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    )
                  : DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _bomId,
                      decoration:
                          const InputDecoration(labelText: 'Công thức (BoM)'),
                      items: [
                        for (final b in list)
                          DropdownMenuItem(
                            value: b.id,
                            child: Text(
                              // Code + name + batch size so same-name recipes
                              // (retired versions, size variants) stay tellable.
                              '${b.productCode} · ${b.productNameVi} — mẻ '
                              '${b.outputQty.toStringAsFixed(0)}${b.uomCode}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _bomId = v),
                    ),
            ),
            const SizedBox(height: BananSpacing.md),
            TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số lượng sản xuất'),
            ),
            if (_error != null) ...[
              const SizedBox(height: BananSpacing.sm),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Đang tạo…' : 'Tạo'),
        ),
      ],
    );
  }
}

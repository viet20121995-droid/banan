import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'production_providers.dart';

/// Receive raw material into stock (nhập kho NVL). Qty is in the product's base
/// unit; the backend rolls AVCO forward with the entered unit cost.
class ReceiptFormScreen extends ConsumerStatefulWidget {
  const ReceiptFormScreen({super.key});

  @override
  ConsumerState<ReceiptFormScreen> createState() => _ReceiptFormScreenState();
}

class _ReceiptFormScreenState extends ConsumerState<ReceiptFormScreen> {
  String? _productId;
  final _qty = TextEditingController();
  final _cost = TextEditingController();
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
    if (_productId == null ||
        qty == null ||
        qty <= 0 ||
        cost == null ||
        cost < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chọn NVL, nhập số lượng > 0 và đơn giá.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final res = await ref.read(manufacturingApiProvider).receive(
          productId: _productId!,
          qty: qty,
          unitCost: cost,
          lotName: _lot.text.trim().isEmpty ? null : _lot.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ref.invalidate(onHandProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã nhập kho.')),
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
    // Only purchased items (raw material + packaging) are received into stock.
    final raw = ref.watch(productsProvider('RAW'));
    final pkg = ref.watch(productsProvider('PACKAGING'));
    final loading = raw.isLoading || pkg.isLoading;
    final list = [
      ...(raw.valueOrNull ?? const []),
      ...(pkg.valueOrNull ?? const []),
    ];
    final selected = list.where((p) => p.id == _productId);
    final uom = selected.isEmpty ? '' : selected.first.uomCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Nhập kho NVL')),
      body: loading && list.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(BananSpacing.lg),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _productId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Nguyên liệu / bao bì'),
                  items: [
                    for (final p in list)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.nameVi} (${p.code})'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _productId = v),
                ),
                const SizedBox(height: BananSpacing.md),
                TextField(
                  controller: _qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
                  ],
                  decoration:
                      InputDecoration(labelText: 'Số lượng', suffixText: uom),
                ),
                const SizedBox(height: BananSpacing.md),
                TextField(
                  controller: _cost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Đơn giá',
                    suffixText: 'đ / đơn vị',
                  ),
                ),
                const SizedBox(height: BananSpacing.md),
                TextField(
                  controller: _lot,
                  decoration: const InputDecoration(
                    labelText: 'Tên lô (nếu có)',
                    helperText: 'Chỉ dùng cho NVL theo lô.',
                  ),
                ),
                const SizedBox(height: BananSpacing.xl),
                PrimaryButton(
                  label: 'Nhập kho',
                  icon: Icons.add_box_outlined,
                  loading: _saving,
                  expand: true,
                  onPressed: _saving ? null : _submit,
                ),
              ],
            ),
    );
  }
}

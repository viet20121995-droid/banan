import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'production_providers.dart';

/// Log a stock loss (hao hụt). Qty is entered in the product's own base unit;
/// the backend defaults the UoM and freezes the loss at the current AVCO.
class ScrapFormScreen extends ConsumerStatefulWidget {
  const ScrapFormScreen({super.key});

  @override
  ConsumerState<ScrapFormScreen> createState() => _ScrapFormScreenState();
}

class _ScrapFormScreenState extends ConsumerState<ScrapFormScreen> {
  String? _productId;
  final _qty = TextEditingController();
  final _reason = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit(List<MfgProduct> products) async {
    final qty = double.tryParse(_qty.text.trim());
    if (_productId == null ||
        qty == null ||
        qty <= 0 ||
        _reason.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chọn sản phẩm, nhập số lượng > 0 và lý do.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final res = await ref.read(manufacturingApiProvider).scrap(
          productId: _productId!,
          qty: qty,
          reason: _reason.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ref.invalidate(onHandProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã ghi hao hụt.')),
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
    final products = ref.watch(productsProvider(null));
    return Scaffold(
      appBar: AppBar(title: const Text('Ghi hao hụt')),
      body: products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (list) {
          final selected = list.where((p) => p.id == _productId);
          final uom = selected.isEmpty ? '' : selected.first.uomCode;
          return ListView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _productId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sản phẩm'),
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
                decoration: InputDecoration(
                  labelText: 'Số lượng',
                  suffixText: uom,
                ),
              ),
              const SizedBox(height: BananSpacing.md),
              TextField(
                controller: _reason,
                decoration: const InputDecoration(
                  labelText: 'Lý do (rơi vỡ, hỏng, quá hạn…)',
                ),
              ),
              const SizedBox(height: BananSpacing.xl),
              PrimaryButton(
                label: 'Ghi hao hụt',
                icon: Icons.delete_outline,
                loading: _saving,
                expand: true,
                onPressed: _saving ? null : () => _submit(list),
              ),
            ],
          );
        },
      ),
    );
  }
}

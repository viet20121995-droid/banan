import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'production_providers.dart';

class _LineDraft {
  _LineDraft({this.componentId, String qty = ''})
      : qtyCtrl = TextEditingController(text: qty);
  String? componentId;
  final TextEditingController qtyCtrl;
}

class _OpDraft {
  _OpDraft({String name = '', this.workCenterId, String minutes = ''})
      : nameCtrl = TextEditingController(text: name),
        minCtrl = TextEditingController(text: minutes);
  final TextEditingController nameCtrl;
  String? workCenterId;
  final TextEditingController minCtrl;
}

/// Create or edit a recipe (BoM). Editing saves a NEW active version server-side,
/// so past production keeps the recipe it was built from. Quantities are in each
/// product's own base unit (no UoM picker).
class BomEditorScreen extends ConsumerStatefulWidget {
  const BomEditorScreen({super.key, this.bomId});
  final String? bomId;

  @override
  ConsumerState<BomEditorScreen> createState() => _BomEditorScreenState();
}

class _BomEditorScreenState extends ConsumerState<BomEditorScreen> {
  final _outputQty = TextEditingController(text: '1000');
  String? _outputProductId;
  final List<_LineDraft> _lines = [_LineDraft()];
  final List<_OpDraft> _ops = [];
  bool _saving = false;
  late bool _editLoading = widget.bomId != null;

  @override
  void initState() {
    super.initState();
    if (widget.bomId != null) {
      Future.microtask(() async {
        final res =
            await ref.read(manufacturingApiProvider).getBom(widget.bomId!);
        if (!mounted) return;
        res.when(
          success: (bom) => setState(() {
            _outputProductId = bom.productId;
            _outputQty.text = bom.outputQty.toStringAsFixed(0);
            _lines
              ..clear()
              ..addAll(
                bom.lines.map(
                  (l) => _LineDraft(
                    componentId: l.componentId,
                    qty: l.qty.toStringAsFixed(0),
                  ),
                ),
              );
            _ops
              ..clear()
              ..addAll(
                bom.operations.map(
                  (o) => _OpDraft(
                    name: o.nameVi,
                    workCenterId: o.workCenterId,
                    minutes: o.durationMinutes.toString(),
                  ),
                ),
              );
            _editLoading = false;
          }),
          failure: (_) => setState(() => _editLoading = false),
        );
      });
    }
  }

  @override
  void dispose() {
    _outputQty.dispose();
    for (final l in _lines) {
      l.qtyCtrl.dispose();
    }
    for (final o in _ops) {
      o.nameCtrl.dispose();
      o.minCtrl.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _submit(List<MfgProduct> products) async {
    final uomOf = {for (final p in products) p.id: p.uomId};
    final outUom = _outputProductId == null ? null : uomOf[_outputProductId];
    final outQty = double.tryParse(_outputQty.text.trim());

    final lines = [
      for (final l in _lines)
        if (l.componentId != null &&
            (double.tryParse(l.qtyCtrl.text.trim()) ?? 0) > 0)
          (
            componentId: l.componentId!,
            qty: double.parse(l.qtyCtrl.text.trim()),
            uomId: uomOf[l.componentId!] ?? '',
          ),
    ];
    if (_outputProductId == null ||
        outUom == null ||
        outUom.isEmpty ||
        outQty == null ||
        outQty <= 0 ||
        lines.isEmpty) {
      _snack('Chọn thành phẩm, sản lượng và ít nhất một nguyên liệu hợp lệ.');
      return;
    }
    final ops = [
      for (final o in _ops)
        if (o.nameCtrl.text.trim().isNotEmpty && o.workCenterId != null)
          (
            nameVi: o.nameCtrl.text.trim(),
            workCenterId: o.workCenterId!,
            durationMinutes: int.tryParse(o.minCtrl.text.trim()) ?? 0,
          ),
    ];

    setState(() => _saving = true);
    final res = await ref.read(manufacturingApiProvider).createBom(
          productId: _outputProductId!,
          outputQty: outQty,
          uomId: outUom,
          lines: lines,
          operations: ops,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ref.invalidate(bomListProvider);
        _snack('Đã lưu công thức.');
        context.pop();
      },
      failure: (f) => _snack('Lỗi: ${f.message ?? f.code}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider(null));
    final workCenters = ref.watch(workCentersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bomId == null ? 'Công thức mới' : 'Sửa công thức'),
      ),
      body: _editLoading
          ? const Center(child: CircularProgressIndicator())
          : products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (list) => _form(list, workCenters.valueOrNull ?? const []),
            ),
    );
  }

  Widget _form(List<MfgProduct> products, List<MfgWorkCenter> workCenters) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(BananSpacing.lg),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _outputProductId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Thành phẩm'),
          items: [
            for (final p in products)
              DropdownMenuItem(
                value: p.id,
                child: Text('${p.nameVi} (${p.code})'),
              ),
          ],
          onChanged: (v) => setState(() => _outputProductId = v),
        ),
        const SizedBox(height: BananSpacing.md),
        TextField(
          controller: _outputQty,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Sản lượng mẻ (theo đơn vị của thành phẩm)',
          ),
        ),
        const SizedBox(height: BananSpacing.xl),
        Text('Nguyên liệu', style: theme.textTheme.titleMedium),
        const SizedBox(height: BananSpacing.sm),
        for (var i = 0; i < _lines.length; i++) _lineRow(i, products),
        TextButton.icon(
          onPressed: () => setState(() => _lines.add(_LineDraft())),
          icon: const Icon(Icons.add),
          label: const Text('Thêm nguyên liệu'),
        ),
        const SizedBox(height: BananSpacing.xl),
        Text('Công đoạn (tuỳ chọn)', style: theme.textTheme.titleMedium),
        const SizedBox(height: BananSpacing.sm),
        for (var i = 0; i < _ops.length; i++) _opRow(i, workCenters),
        TextButton.icon(
          onPressed: () => setState(() => _ops.add(_OpDraft())),
          icon: const Icon(Icons.add),
          label: const Text('Thêm công đoạn'),
        ),
        const SizedBox(height: BananSpacing.xl),
        PrimaryButton(
          label: 'Lưu công thức',
          icon: Icons.save_outlined,
          loading: _saving,
          expand: true,
          onPressed: _saving ? null : () => _submit(products),
        ),
      ],
    );
  }

  Widget _lineRow(int i, List<MfgProduct> products) {
    final line = _lines[i];
    final uom = products.where((p) => p.id == line.componentId);
    final suffix = uom.isEmpty ? '' : uom.first.uomCode;
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: line.componentId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Nguyên liệu',
                isDense: true,
              ),
              items: [
                for (final p in products)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.nameVi} (${p.code})'),
                  ),
              ],
              onChanged: (v) => setState(() => line.componentId = v),
            ),
          ),
          const SizedBox(width: BananSpacing.sm),
          Expanded(
            flex: 2,
            child: TextField(
              controller: line.qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: 'SL',
                suffixText: suffix,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Xoá',
            onPressed: () => setState(() {
              line.qtyCtrl.dispose();
              _lines.removeAt(i);
            }),
          ),
        ],
      ),
    );
  }

  Widget _opRow(int i, List<MfgWorkCenter> workCenters) {
    final op = _ops[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: op.nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên công đoạn',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: BananSpacing.sm),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: op.workCenterId,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Tổ/máy', isDense: true),
              items: [
                for (final w in workCenters)
                  DropdownMenuItem(value: w.id, child: Text(w.nameVi)),
              ],
              onChanged: (v) => setState(() => op.workCenterId = v),
            ),
          ),
          const SizedBox(width: BananSpacing.sm),
          Expanded(
            flex: 2,
            child: TextField(
              controller: op.minCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  const InputDecoration(labelText: 'Phút', isDense: true),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Xoá',
            onPressed: () => setState(() {
              op.nameCtrl.dispose();
              op.minCtrl.dispose();
              _ops.removeAt(i);
            }),
          ),
        ],
      ),
    );
  }
}

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

class _QcDraft {
  _QcDraft({
    String titleVi = '',
    String titleEn = '',
    this.testType = 'PASS_FAIL',
    String min = '',
    String max = '',
    String unit = '',
  })  : titleViCtrl = TextEditingController(text: titleVi),
        titleEnCtrl = TextEditingController(text: titleEn),
        minCtrl = TextEditingController(text: min),
        maxCtrl = TextEditingController(text: max),
        unitCtrl = TextEditingController(text: unit);

  final TextEditingController titleViCtrl;
  final TextEditingController titleEnCtrl;
  String testType;
  final TextEditingController minCtrl;
  final TextEditingController maxCtrl;
  final TextEditingController unitCtrl;

  void dispose() {
    titleViCtrl.dispose();
    titleEnCtrl.dispose();
    minCtrl.dispose();
    maxCtrl.dispose();
    unitCtrl.dispose();
  }
}

class _OpDraft {
  _OpDraft({
    String name = '',
    this.workCenterId,
    String minutes = '',
    List<_QcDraft>? qualityPoints,
  })  : qualityPoints = qualityPoints ?? [],
        nameCtrl = TextEditingController(text: name),
        minCtrl = TextEditingController(text: minutes);
  final TextEditingController nameCtrl;
  String? workCenterId;
  final TextEditingController minCtrl;
  final List<_QcDraft> qualityPoints;
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
                    qualityPoints: [
                      for (final q in o.qualityPoints)
                        _QcDraft(
                          titleVi: q.titleVi,
                          titleEn: q.titleEn,
                          testType: q.testType,
                          min: q.isMeasure ? q.normMin.toString() : '',
                          max: q.isMeasure ? q.normMax.toString() : '',
                          unit: q.unit ?? '',
                        ),
                    ],
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
      for (final q in o.qualityPoints) {
        q.dispose();
      }
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
            qualityPoints: [
              for (final q in o.qualityPoints)
                if (q.titleViCtrl.text.trim().isNotEmpty)
                  (
                    titleVi: q.titleViCtrl.text.trim(),
                    titleEn: q.titleEnCtrl.text.trim(),
                    testType: q.testType,
                    normMin: q.testType == 'MEASURE'
                        ? double.tryParse(q.minCtrl.text.trim())
                        : null,
                    normMax: q.testType == 'MEASURE'
                        ? double.tryParse(q.maxCtrl.text.trim())
                        : null,
                    unit:
                        q.testType == 'MEASURE' ? q.unitCtrl.text.trim() : null,
                  ),
            ],
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
    // A recipe outputs something the kitchen MAKES; a FINISHED good is never an
    // ingredient. Backend enforces the same split (MFG_BOM_OUTPUT_TYPE /
    // MFG_BOM_COMPONENT_TYPE) — these filters just keep the pickers honest.
    final outputs = products
        .where((p) => p.type == 'SEMI' || p.type == 'FINISHED')
        .toList();
    return ListView(
      padding: const EdgeInsets.all(BananSpacing.lg),
      children: [
        DropdownButtonFormField<String>(
          initialValue: outputs.any((p) => p.id == _outputProductId)
              ? _outputProductId
              : null,
          isExpanded: true,
          decoration:
              const InputDecoration(labelText: 'Thành phẩm / bán thành phẩm'),
          items: [
            for (final p in outputs)
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
    // Ingredients: anything BUT a finished good (RAW / PACKAGING / SEMI).
    final components = products.where((p) => p.type != 'FINISHED').toList();
    final uom = components.where((p) => p.id == line.componentId);
    final suffix = uom.isEmpty ? '' : uom.first.uomCode;
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: components.any((p) => p.id == line.componentId)
                  ? line.componentId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Nguyên liệu',
                isDense: true,
              ),
              items: [
                for (final p in components)
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
    return Container(
      margin: const EdgeInsets.only(bottom: BananSpacing.md),
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BananRadii.rmd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '${i + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
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
                  decoration: const InputDecoration(
                    labelText: 'Tổ/máy',
                    isDense: true,
                  ),
                  items: [
                    for (final w in workCenters)
                      DropdownMenuItem(value: w.id, child: Text(w.nameVi)),
                  ],
                  onChanged: (v) => setState(() => op.workCenterId = v),
                ),
              ),
              const SizedBox(width: BananSpacing.sm),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: op.minCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Phút chuẩn',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Xoá công đoạn',
                onPressed: () => setState(() {
                  op.nameCtrl.dispose();
                  op.minCtrl.dispose();
                  for (final q in op.qualityPoints) {
                    q.dispose();
                  }
                  _ops.removeAt(i);
                }),
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.sm),
          Row(
            children: [
              Text(
                'Điểm kiểm soát QC',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    setState(() => op.qualityPoints.add(_QcDraft())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm điểm QC'),
              ),
            ],
          ),
          if (op.qualityPoints.isEmpty)
            Text(
              'Chưa có điểm QC. Công đoạn vẫn chạy nhưng không có bước kiểm tra chất lượng.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (var q = 0; q < op.qualityPoints.length; q++) _qcRow(op, q),
        ],
      ),
    );
  }

  Widget _qcRow(_OpDraft op, int index) {
    final q = op.qualityPoints[index];
    final measure = q.testType == 'MEASURE';
    return Padding(
      padding: const EdgeInsets.only(top: BananSpacing.sm),
      child: Wrap(
        spacing: BananSpacing.sm,
        runSpacing: BananSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 250,
            child: TextField(
              controller: q.titleViCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên kiểm tra',
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              initialValue: q.testType,
              decoration: const InputDecoration(
                labelText: 'Cách kiểm tra',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'PASS_FAIL',
                  child: Text('Đạt / Không đạt'),
                ),
                DropdownMenuItem(value: 'MEASURE', child: Text('Nhập số đo')),
              ],
              onChanged: (v) => setState(() => q.testType = v ?? 'PASS_FAIL'),
            ),
          ),
          if (measure) ...[
            SizedBox(
              width: 105,
              child: TextField(
                controller: q.minCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Tối thiểu',
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 105,
              child: TextField(
                controller: q.maxCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Tối đa', isDense: true),
              ),
            ),
            SizedBox(
              width: 90,
              child: TextField(
                controller: q.unitCtrl,
                decoration:
                    const InputDecoration(labelText: 'Đơn vị', isDense: true),
              ),
            ),
          ],
          IconButton(
            onPressed: () => setState(() {
              q.dispose();
              op.qualityPoints.removeAt(index);
            }),
            icon: const Icon(Icons.close),
            tooltip: 'Xoá điểm QC',
          ),
        ],
      ),
    );
  }
}

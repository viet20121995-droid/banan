import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'production_providers.dart';
import 'products_screen.dart' show mfgTypeLabels;

/// Create/edit a manufacturing product (NVL, bao bì, bán thành phẩm, thành
/// phẩm). Editing an archived product offers reactivation; the base UoM of a
/// product that already has stock moves is locked server-side.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  /// null = create.
  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _code = TextEditingController();
  final _nameVi = TextEditingController();
  final _nameEn = TextEditingController();
  final _expDays = TextEditingController(text: '0');
  final _stdCost = TextEditingController(text: '0');
  final _reorderPoint = TextEditingController(text: '0');

  String? _categoryId;
  String? _uomId;
  String _type = 'RAW';
  bool _lotTracked = false;
  bool _useExpiration = false;
  bool _active = true;

  bool _seeded = false;
  bool _saving = false;

  bool get _isEdit => widget.productId != null;

  @override
  void dispose() {
    _code.dispose();
    _nameVi.dispose();
    _nameEn.dispose();
    _expDays.dispose();
    _stdCost.dispose();
    _reorderPoint.dispose();
    super.dispose();
  }

  void _seed(MfgProduct p) {
    if (_seeded) return;
    _seeded = true;
    _code.text = p.code;
    _nameVi.text = p.nameVi;
    _nameEn.text = p.nameEn;
    _expDays.text = '${p.expirationDays}';
    _stdCost.text = p.standardCost.toStringAsFixed(0);
    _reorderPoint.text = p.reorderPoint == p.reorderPoint.roundToDouble()
        ? '${p.reorderPoint.round()}'
        : '${p.reorderPoint}';
    _categoryId = p.categoryId.isEmpty ? null : p.categoryId;
    _uomId = p.uomId.isEmpty ? null : p.uomId;
    _type = p.type;
    _lotTracked = p.tracking == 'LOT';
    _useExpiration = p.useExpiration;
    _active = p.active;
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    final nameVi = _nameVi.text.trim();
    final expDays = int.tryParse(_expDays.text.trim()) ?? 0;
    // Digits-only field (VND has no decimals) — '.' would silently parse
    // '15.000' as 15, so the formatter below never lets it in.
    final stdCost = (int.tryParse(_stdCost.text.trim()) ?? 0).toDouble();
    final reorderPoint = double.tryParse(_reorderPoint.text.trim()) ?? 0;
    if (code.isEmpty ||
        nameVi.isEmpty ||
        _categoryId == null ||
        _uomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Điền mã, tên, nhóm và đơn vị.')),
      );
      return;
    }
    // HSD bật mà 0 ngày = mọi lô sinh ra không có hạn — backend cũng từ chối.
    if (_lotTracked && _useExpiration && expDays < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bật HSD thì số ngày sử dụng phải ≥ 1.')),
      );
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(manufacturingApiProvider);
    final res = _isEdit
        ? await api.updateProduct(
            widget.productId!,
            code: code,
            nameVi: nameVi,
            nameEn: _nameEn.text.trim(),
            categoryId: _categoryId,
            uomId: _uomId,
            type: _type,
            tracking: _lotTracked ? 'LOT' : 'NONE',
            useExpiration: _lotTracked && _useExpiration,
            expirationDays: expDays,
            standardCost: stdCost,
            reorderPoint: reorderPoint,
            active: _active,
          )
        : await api.createProduct(
            code: code,
            nameVi: nameVi,
            nameEn: _nameEn.text.trim(),
            categoryId: _categoryId!,
            uomId: _uomId!,
            type: _type,
            tracking: _lotTracked ? 'LOT' : 'NONE',
            useExpiration: _lotTracked && _useExpiration,
            expirationDays: expDays,
            standardCost: stdCost,
            reorderPoint: reorderPoint,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ref
          ..invalidate(adminProductsProvider)
          ..invalidate(productsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Đã lưu.' : 'Đã thêm sản phẩm.')),
        );
        // Deep-link/refresh gives a one-entry stack — pop() would throw.
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/production/products');
        }
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${f.message ?? f.code}')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uoms = ref.watch(mfgUomsProvider);
    final categories = ref.watch(mfgCategoriesProvider);

    // Edit mode: seed once from the loaded product — but never show an editable
    // form before the product arrives (a deep-link/browser refresh lands here
    // with the provider still loading; a blank "edit" form that saves
    // create-defaults over the real product would corrupt it).
    if (_isEdit && !_seeded) {
      final products = ref.watch(adminProductsProvider);
      final gate = products.when<Widget?>(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: ErrorState(
            title: 'Không tải được sản phẩm',
            message: '$e',
            onRetry: () => ref.invalidate(adminProductsProvider),
          ),
        ),
        data: (rows) {
          final loaded =
              rows.where((p) => p.id == widget.productId).firstOrNull;
          if (loaded == null) {
            return const Center(
              child: EmptyState(
                title: 'Không tìm thấy sản phẩm',
                icon: Icons.search_off,
              ),
            );
          }
          _seed(loaded);
          return null; // seeded — fall through to the form
        },
      );
      if (gate != null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Sửa sản phẩm')),
          body: gate,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm / NVL'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(BananSpacing.lg),
        children: [
          TextField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'Mã (SKU)',
              hintText: 'VD: RAW-FLOUR-13',
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: BananSpacing.md),
          TextField(
            controller: _nameVi,
            decoration: const InputDecoration(labelText: 'Tên (tiếng Việt)'),
          ),
          const SizedBox(height: BananSpacing.md),
          TextField(
            controller: _nameEn,
            decoration: const InputDecoration(
              labelText: 'Tên (tiếng Anh) — tuỳ chọn',
            ),
          ),
          const SizedBox(height: BananSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Loại'),
            items: [
              for (final e in mfgTypeLabels.entries)
                DropdownMenuItem(
                  value: e.key,
                  child: Text('${e.value} (${e.key})'),
                ),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'RAW'),
          ),
          const SizedBox(height: BananSpacing.md),
          categories.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Lỗi tải nhóm: $e'),
            data: (rows) => DropdownButtonFormField<String>(
              initialValue:
                  rows.any((c) => c.id == _categoryId) ? _categoryId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Nhóm sản phẩm'),
              items: [
                for (final c in rows)
                  DropdownMenuItem(value: c.id, child: Text(c.nameVi)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ),
          const SizedBox(height: BananSpacing.md),
          uoms.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Lỗi tải đơn vị: $e'),
            data: (rows) => DropdownButtonFormField<String>(
              initialValue: rows.any((u) => u.id == _uomId) ? _uomId : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Đơn vị gốc',
                helperText:
                    'Khoá sau khi có giao dịch kho — chọn đúng ngay từ đầu.',
              ),
              items: [
                for (final u in rows)
                  DropdownMenuItem(
                    value: u.id,
                    child: Text('${u.code} — ${u.nameVi}'),
                  ),
              ],
              onChanged: (v) => setState(() => _uomId = v),
            ),
          ),
          const SizedBox(height: BananSpacing.md),
          TextField(
            controller: _stdCost,
            decoration: const InputDecoration(
              labelText: 'Giá vốn chuẩn (đ / đơn vị gốc)',
              helperText:
                  'AVCO tự cập nhật khi nhập kho; đây là giá tham chiếu.',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: BananSpacing.md),
          TextField(
            controller: _reorderPoint,
            decoration: const InputDecoration(
              labelText: 'Mức tồn tối thiểu (đơn vị gốc)',
              helperText:
                  'Tốc độ bán × thời gian làm/mua (+ dự phòng). Tồn dưới mức '
                  'này sẽ hiện ở Gợi ý mua hàng. 0 = không theo dõi.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
            ],
          ),
          const SizedBox(height: BananSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Theo dõi theo lô'),
            subtitle: const Text('Bắt buộc để truy vết và quản lý HSD'),
            value: _lotTracked,
            onChanged: (v) => setState(() => _lotTracked = v),
          ),
          if (_lotTracked) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Có hạn sử dụng'),
              value: _useExpiration,
              onChanged: (v) => setState(() => _useExpiration = v),
            ),
            if (_useExpiration)
              TextField(
                controller: _expDays,
                decoration: const InputDecoration(
                  labelText: 'Số ngày sử dụng (từ ngày sản xuất/nhập)',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
          ],
          if (_isEdit)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Đang sử dụng'),
              subtitle:
                  const Text('Tắt để lưu trữ — ẩn khỏi các danh sách chọn'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          const SizedBox(height: BananSpacing.xl),
          PrimaryButton(
            label: _isEdit ? 'Lưu thay đổi' : 'Thêm sản phẩm',
            loading: _saving,
            expand: true,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}

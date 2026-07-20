import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/cover_image_picker.dart';
import '../../shared/shell/merchant_shell.dart';
import '../menu_mgmt/menu_list_screen.dart' show merchantMenuControllerProvider;

/// Editor for a combo. Same screen handles "new" (no id) and "edit" (id).
/// Grab-Merchant-style — single scroll surface, live-updated "khách tiết
/// kiệm" pill, searchable product picker bottom sheet. Auto-derives a
/// slug from the name so the merchant doesn't have to think about it.
class BundleEditorScreen extends ConsumerStatefulWidget {
  const BundleEditorScreen({this.bundleId, super.key});
  final String? bundleId;

  @override
  ConsumerState<BundleEditorScreen> createState() => _BundleEditorScreenState();
}

class _BundleEditorScreenState extends ConsumerState<BundleEditorScreen> {
  // ── Form state ─────────────────────────────────────────────────────
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  String? _imageUrl;
  bool _isActive = true;
  bool _isPinnedToHome = false;

  /// Tracks "merchant edited slug manually" — when false we keep
  /// auto-slugging from the name as they type.
  bool _slugAutoSync = true;

  /// Working item list — `variantId == null` means "use default variant".
  final List<_DraftItem> _items = [];

  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get _isCreating => widget.bundleId == null;

  @override
  void initState() {
    super.initState();
    if (!_isCreating) {
      _load();
    } else {
      _price.text = '0';
    }
    _name.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _name
      ..removeListener(_onNameChanged)
      ..dispose();
    _slug.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ref
        .read(bundlesApiProvider)
        .merchantDetail(widget.bundleId!);
    if (!mounted) return;
    res.when(
      success: (b) {
        _name.text = b.name;
        _slug.text = b.slug;
        _slugAutoSync = false; // existing bundle: never overwrite slug
        _description.text = b.description ?? '';
        _imageUrl = b.imageUrl;
        _price.text = b.priceVnd.toString();
        _isActive = b.isActive;
        _isPinnedToHome = b.isPinnedToHome;
        _items
          ..clear()
          ..addAll(b.items.map(_DraftItem.fromBundleItem));
        setState(() => _loading = false);
      },
      failure: (f) => setState(() {
        _loading = false;
        _error = authFailureMessage(f);
      }),
    );
  }

  void _onNameChanged() {
    if (!_slugAutoSync) return;
    _slug.text = _slugify(_name.text);
  }

  String _slugify(String input) {
    var s = input.toLowerCase().trim();
    const vn = {
      'á': 'a', 'à': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
      'ă': 'a', 'ắ': 'a', 'ằ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
      'â': 'a', 'ấ': 'a', 'ầ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
      'é': 'e', 'è': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
      'ê': 'e', 'ế': 'e', 'ề': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
      'í': 'i', 'ì': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
      'ó': 'o', 'ò': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
      'ô': 'o', 'ố': 'o', 'ồ': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
      'ơ': 'o', 'ớ': 'o', 'ờ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
      'ú': 'u', 'ù': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
      'ư': 'u', 'ứ': 'u', 'ừ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
      'ý': 'y', 'ỳ': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
      'đ': 'd',
    };
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      buf.write(vn[ch] ?? ch);
    }
    s = buf
        .toString()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s;
  }

  /// "Khách tiết kiệm X" computed client-side — same formula as the
  /// backend `savings()` method, lets the merchant see the impact of
  /// quantity changes instantly without saving.
  int _calcSavings() {
    var regular = 0;
    for (final it in _items) {
      final base = it.product?.basePrice ?? 0;
      final delta = it.variant?.priceDelta ?? 0;
      regular += ((base + delta) * it.quantity).round();
    }
    final price = int.tryParse(_price.text.trim()) ?? 0;
    final saved = regular - price;
    return saved > 0 ? saved : 0;
  }

  Future<void> _addItem() async {
    final picked = await _openProductPicker();
    if (picked == null) return;
    setState(() {
      // Merge if same (product, variant) already in list — bump qty.
      for (final it in _items) {
        if (it.product?.id == picked.product?.id &&
            it.variant?.id == picked.variant?.id) {
          it.quantity += picked.quantity;
          return;
        }
      }
      _items.add(picked);
    });
  }

  Future<_DraftItem?> _openProductPicker() async {
    return showModalBottomSheet<_DraftItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ProductPickerSheet(),
    );
  }

  Future<void> _save() async {
    final price = int.tryParse(_price.text.trim());
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Tên combo tối thiểu 2 ký tự.');
      return;
    }
    if (_slug.text.trim().length < 2) {
      setState(() => _error = 'Slug không hợp lệ.');
      return;
    }
    if (price == null || price < 1000) {
      setState(() => _error = 'Giá combo phải ≥ 1.000₫.');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Combo phải có ít nhất 1 sản phẩm.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'slug': _slug.text.trim(),
      'description': _description.text.trim(),
      'imageUrl': _imageUrl ?? '',
      'priceVnd': price,
      'isActive': _isActive,
      'isPinnedToHome': _isPinnedToHome,
      'items': _items
          .map((it) => {
                'productId': it.product!.id,
                if (it.variant != null) 'variantId': it.variant!.id,
                'quantity': it.quantity,
              },)
          .toList(),
    };
    final api = ref.read(bundlesApiProvider);
    final res = _isCreating
        ? await api.create(body)
        : await api.updateBundle(widget.bundleId!, body);
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isCreating ? 'Đã tạo combo.' : 'Đã lưu thay đổi.',
            ),
          ),
        );
        context.pop();
      },
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xoá combo "${_name.text}"?'),
        content: const Text(
          'Combo sẽ bị xoá hoàn toàn. Đơn hàng đã có không bị ảnh hưởng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    final res =
        await ref.read(bundlesApiProvider).deleteBundle(widget.bundleId!);
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xoá combo.')),
        );
        context.pop();
      },
      failure: (f) => setState(() => _error = authFailureMessage(f)),
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
    final savings = _calcSavings();

    return MerchantShell(
      title: _isCreating ? 'Combo mới' : 'Sửa combo',
      action: _isCreating
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Xoá combo',
              onPressed: _saving ? null : _delete,
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    BananSpacing.lg,
                    BananSpacing.md,
                    BananSpacing.lg,
                    96,
                  ),
                  children: [
                    // ── Cover image ──────────────────────────────────
                    CoverImagePicker(
                      label: 'Ảnh combo (tuỳ chọn)',
                      url: _imageUrl,
                      onChanged: (url) => setState(() => _imageUrl = url),
                      recommendedSize: '1200×900px (tỉ lệ 4:3)',
                    ),
                    const SizedBox(height: BananSpacing.lg),

                    // ── Name + slug ─────────────────────────────────
                    TextField(
                      controller: _name,
                      maxLength: 120,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Tên combo *',
                        hintText: 'vd: Combo bữa sáng',
                      ),
                    ),
                    const SizedBox(height: BananSpacing.sm),
                    TextField(
                      controller: _slug,
                      maxLength: 140,
                      onChanged: (_) => _slugAutoSync = false,
                      decoration: const InputDecoration(
                        labelText: 'Slug',
                        helperText:
                            'Tự sinh từ tên, dùng cho URL. Chỉ chứa '
                            'chữ thường + số + dấu gạch.',
                      ),
                    ),
                    const SizedBox(height: BananSpacing.sm),
                    TextField(
                      controller: _description,
                      maxLength: 2000,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả (tuỳ chọn)',
                        hintText:
                            'Mô tả ngắn để khách hiểu combo gồm gì và lý do '
                            'nên chọn. Hiện trên trang combo và thẻ '
                            'sản phẩm.',
                      ),
                    ),
                    const SizedBox(height: BananSpacing.lg),

                    // ── Items ──────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(BananSpacing.md),
                      decoration: BoxDecoration(
                        borderRadius: BananRadii.rmd,
                        color: theme.colorScheme.surface,
                        border: Border.all(
                          color: theme.dividerTheme.color ?? Colors.black12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Sản phẩm trong combo',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _saving ? null : _addItem,
                                icon: const Icon(Icons.add),
                                label: const Text('Thêm sản phẩm'),
                              ),
                            ],
                          ),
                          if (_items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: BananSpacing.md,
                              ),
                              child: Text(
                                'Chưa có sản phẩm. Bấm "Thêm sản phẩm" để '
                                'chọn từ danh mục.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            )
                          else
                            for (var i = 0; i < _items.length; i++)
                              _ItemRow(
                                key: ValueKey(
                                  '${_items[i].product?.id}:'
                                  '${_items[i].variant?.id}',
                                ),
                                item: _items[i],
                                onQuantityChanged: (q) {
                                  if (q < 1) return;
                                  setState(() => _items[i].quantity = q);
                                },
                                onVariantChanged: (v) => setState(() {
                                  _items[i].variant = v;
                                }),
                                onRemove: () => setState(() => _items.removeAt(i)),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: BananSpacing.lg),

                    // ── Price + savings preview ─────────────────────
                    Container(
                      padding: const EdgeInsets.all(BananSpacing.md),
                      decoration: BoxDecoration(
                        borderRadius: BananRadii.rmd,
                        color: BananColors.primary.withValues(alpha: 0.06),
                        border: Border.all(
                          color: BananColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _price,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Giá combo (₫) *',
                              helperText:
                                  'Giá bán cố định cho cả combo. Thường '
                                  'thấp hơn 10-25% so với tổng giá lẻ.',
                              suffixText: '₫',
                            ),
                          ),
                          if (_items.isNotEmpty) ...[
                            const SizedBox(height: BananSpacing.sm),
                            Row(
                              children: [
                                const Icon(
                                  Icons.savings_outlined,
                                  color: BananColors.success,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    savings > 0
                                        ? 'Khách tiết kiệm ${fmt.format(savings)} so với mua lẻ.'
                                        : 'Giá combo hiện cao hơn hoặc bằng tổng giá lẻ, khách không tiết kiệm.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: savings > 0
                                          ? BananColors.success
                                          : theme.colorScheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: BananSpacing.lg),

                    // ── Visibility toggles ─────────────────────────
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isActive,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _isActive = v),
                      title: const Text('Đang bán'),
                      subtitle: Text(
                        _isActive
                            ? 'Khách hàng nhìn thấy combo trong menu.'
                            : 'Combo bị ẩn, khách hàng không nhìn thấy.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isPinnedToHome,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _isPinnedToHome = v),
                      title: const Text('Ghim lên trang chủ'),
                      subtitle: Text(
                        _isPinnedToHome
                            ? 'Combo xuất hiện trong dải "Combo nổi bật" trên home.'
                            : 'Chỉ hiển thị trong trang menu thường.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: BananSpacing.sm),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: BananSpacing.lg),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isCreating ? 'Tạo combo' : 'Lưu thay đổi'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DraftItem {
  _DraftItem({
    required this.product,
    required this.quantity,
    this.variant,
  });

  factory _DraftItem.fromBundleItem(BundleItem b) => _DraftItem(
        product: b.product,
        variant: b.variant,
        quantity: b.quantity,
      );

  Product? product;
  ProductVariant? variant;
  int quantity;
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onQuantityChanged,
    required this.onVariantChanged,
    required this.onRemove,
    super.key,
  });
  final _DraftItem item;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<ProductVariant?> onVariantChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variants = item.product?.variants ?? const [];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BananSpacing.xs),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BananRadii.rmd,
            child: SizedBox(
              width: 48,
              height: 48,
              child: item.product?.coverImage == null
                  ? Container(
                      color: BananColors.surfaceDim,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.bakery_dining_rounded,
                        color: BananColors.cocoaSoft,
                      ),
                    )
                  : Image.network(item.product!.coverImage!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: BananSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product?.name ?? '—',
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (variants.length > 1)
                  DropdownButton<String?>(
                    isDense: true,
                    value: item.variant?.id,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'Mặc định',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      for (final v in variants)
                        DropdownMenuItem<String?>(
                          value: v.id,
                          child: Text(
                            v.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      final v = id == null
                          ? null
                          : variants.firstWhere((v) => v.id == id);
                      onVariantChanged(v);
                    },
                  ),
              ],
            ),
          ),
          // Quantity stepper
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => onQuantityChanged(item.quantity - 1),
              ),
              SizedBox(
                width: 24,
                child: Text(
                  '${item.quantity}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => onQuantityChanged(item.quantity + 1),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onRemove,
            tooltip: 'Xoá khỏi combo',
          ),
        ],
      ),
    );
  }
}

/// Searchable product picker bottom sheet — same pattern Grab uses.
class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet();

  @override
  ConsumerState<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(merchantMenuControllerProvider);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final q = _query.toLowerCase().trim();
    final list = state.products
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BananSpacing.lg,
                0,
                BananSpacing.lg,
                BananSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Chọn sản phẩm thêm vào combo',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: BananSpacing.sm),
                  TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Tìm sản phẩm theo tên',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        'Không tìm thấy sản phẩm.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BananSpacing.lg,
                      ),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final p = list[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: p.coverImage == null
                              ? const CircleAvatar(
                                  backgroundColor: BananColors.surfaceDim,
                                  child: Icon(
                                    Icons.bakery_dining_rounded,
                                    color: BananColors.cocoaSoft,
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundImage:
                                      NetworkImage(p.coverImage!),
                                ),
                          title: Text(p.name),
                          subtitle: Text(
                            'Từ ${fmt.format(p.minPrice)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          onTap: () => Navigator.of(context).pop(
                            _DraftItem(product: p, quantity: 1),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

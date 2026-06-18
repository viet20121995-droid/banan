import 'dart:async';

import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/cover_image_picker.dart';
import 'collections_list_screen.dart';

final _editorCollectionProvider =
    FutureProvider.autoDispose.family<Collection, String>((ref, id) async {
  final repo = ref.watch(collectionsRepositoryProvider);
  final res = await repo.get(id);
  return res.when(
    success: (c) => c,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

/// Search the chain-wide catalog for the product picker. Querying server-side
/// (perPage 50) means the picker isn't limited to a stale first page and can
/// find any product by name — fixing the old chip list that only showed the
/// menu controller's first page.
final _pickerResultsProvider =
    FutureProvider.autoDispose.family<List<Product>, String>((ref, query) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final res = await repo.merchantProducts(
    q: query.trim().isEmpty ? null : query.trim(),
    perPage: 50,
  );
  return res.when(success: (page) => page.items, failure: (_) => <Product>[]);
});

class CollectionEditorScreen extends ConsumerStatefulWidget {
  const CollectionEditorScreen({this.collectionId, super.key});

  final String? collectionId;
  bool get isEditing => collectionId != null;

  @override
  ConsumerState<CollectionEditorScreen> createState() =>
      _CollectionEditorScreenState();
}

class _CollectionEditorScreenState
    extends ConsumerState<CollectionEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _description = TextEditingController();
  String? _coverUrl;
  bool _isPinnedToHome = false;
  bool _isActive = true;
  int _sortOrder = 0;
  final List<String> _selectedProductIds = [];
  // Product details (image/name/price) for rendering the selected rows, seeded
  // from the loaded collection's items and augmented as the merchant picks
  // products from search — so a selected row renders even when it's not in the
  // current search results.
  final Map<String, Product> _productById = {};

  bool _saving = false;
  bool _initialized = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    super.dispose();
  }

  void _hydrateFrom(Collection c) {
    if (_initialized) return;
    _initialized = true;
    _name.text = c.name;
    _slug.text = c.slug;
    _description.text = c.description ?? '';
    _coverUrl = c.imageUrl;
    _isPinnedToHome = c.isPinnedToHome;
    _isActive = c.isActive;
    _sortOrder = c.sortOrder;
    _selectedProductIds
      ..clear()
      ..addAll(c.items.map((i) => i.productId));
    _productById.clear();
    for (final i in c.items) {
      if (i.product != null) _productById[i.productId] = i.product!;
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = CollectionDraft(
      name: _name.text.trim(),
      slug: _slug.text.trim(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      imageUrl: _coverUrl,
      isPinnedToHome: _isPinnedToHome,
      isActive: _isActive,
      sortOrder: _sortOrder,
      items: [
        for (var i = 0; i < _selectedProductIds.length; i++)
          CollectionItemDraft(
            productId: _selectedProductIds[i],
            sortOrder: i,
          ),
      ],
    );

    final repo = ref.read(collectionsRepositoryProvider);
    final result = widget.isEditing
        ? await repo.update(widget.collectionId!, draft)
        : await repo.create(draft);

    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) {
        ref.invalidate(collectionsControllerProvider);
        context.pop();
      },
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing && !_initialized) {
      final async = ref.watch(_editorCollectionProvider(widget.collectionId!));
      return async.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(body: ErrorState(message: e.toString())),
        data: (c) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFrom(c));
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Sửa bộ sưu tập' : 'Tạo bộ sưu tập'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => context.pop(),
            child: const Text('Huỷ'),
          ),
          const SizedBox(width: BananSpacing.sm),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Lưu'),
          ),
          const SizedBox(width: BananSpacing.md),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(BananSpacing.xl),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(BananSpacing.md),
                        margin:
                            const EdgeInsets.only(bottom: BananSpacing.lg),
                        decoration: BoxDecoration(
                          borderRadius: BananRadii.rmd,
                          color: Theme.of(context)
                              .colorScheme
                              .errorContainer
                              .withValues(alpha: 0.4),
                        ),
                        child: Text(_error!),
                      ),
                    _Section(
                      title: 'Thông tin chung',
                      children: [
                        TextFormField(
                          controller: _name,
                          maxLength: 120,
                          decoration: const InputDecoration(labelText: 'Tên'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Bắt buộc'
                              : null,
                          onChanged: (v) {
                            if (_slug.text.isEmpty) {
                              _slug.text = _slugify(v);
                            }
                          },
                        ),
                        const SizedBox(height: BananSpacing.md),
                        TextFormField(
                          controller: _slug,
                          maxLength: 160,
                          decoration: const InputDecoration(
                            labelText: 'Slug URL',
                            helperText: 'chữ thường, dấu gạch, duy nhất theo cửa hàng',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Bắt buộc'
                              : null,
                        ),
                        const SizedBox(height: BananSpacing.md),
                        TextFormField(
                          controller: _description,
                          maxLines: 2,
                          maxLength: 400,
                          decoration: const InputDecoration(
                            labelText: 'Mô tả (tuỳ chọn)',
                            helperText:
                                'Hiển thị dưới tiêu đề ở trang chủ khách hàng',
                          ),
                        ),
                        const SizedBox(height: BananSpacing.lg),
                        CoverImagePicker(
                          url: _coverUrl,
                          helperText:
                              'Ảnh banner carousel trên trang chủ khách hàng.',
                          recommendedSize: '1600×900px (tỉ lệ 16:9)',
                          onChanged: (url) =>
                              setState(() => _coverUrl = url),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Hiển thị',
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ghim lên trang chủ'),
                          subtitle: const Text(
                            'Bộ sưu tập được ghim sẽ hiện dạng carousel '
                            'ngang trên màn hình thực đơn.',
                          ),
                          value: _isPinnedToHome,
                          onChanged: (v) =>
                              setState(() => _isPinnedToHome = v),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Đang bật'),
                          subtitle: const Text(
                            'Bộ sưu tập tạm ẩn sẽ không hiện với khách '
                            'nhưng vẫn lưu để tái sử dụng.',
                          ),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                        const SizedBox(height: BananSpacing.sm),
                        Row(
                          children: [
                            const SizedBox(width: BananSpacing.xs),
                            const Text('Thứ tự hiển thị'),
                            const SizedBox(width: BananSpacing.md),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: '$_sortOrder',
                                keyboardType: TextInputType.number,
                                onChanged: (v) =>
                                    _sortOrder = int.tryParse(v) ?? 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _ProductsPicker(
                      selectedIds: _selectedProductIds,
                      productById: _productById,
                      onToggle: (p) => setState(() {
                        if (_selectedProductIds.contains(p.id)) {
                          _selectedProductIds.remove(p.id);
                        } else {
                          _selectedProductIds.add(p.id);
                          _productById[p.id] = p;
                        }
                      }),
                      onReorder: (oldIndex, newIndex) => setState(() {
                        final id = _selectedProductIds.removeAt(oldIndex);
                        _selectedProductIds.insert(
                          newIndex > oldIndex ? newIndex - 1 : newIndex,
                          id,
                        );
                      }),
                      onRemove: (id) =>
                          setState(() => _selectedProductIds.remove(id)),
                    ),
                    const SizedBox(height: BananSpacing.huge),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _slugify(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: BananSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

/// Searchable product picker. The merchant types in a search box (server-side
/// search via [_pickerResultsProvider]); tapping a result toggles it in/out of
/// the collection. Selected products show as a reorderable list above the
/// search so order is editable without hunting through every product.
class _ProductsPicker extends ConsumerStatefulWidget {
  const _ProductsPicker({
    required this.selectedIds,
    required this.productById,
    required this.onToggle,
    required this.onReorder,
    required this.onRemove,
  });

  final List<String> selectedIds;
  final Map<String, Product> productById;
  final ValueChanged<Product> onToggle;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<String> onRemove;

  @override
  ConsumerState<_ProductsPicker> createState() => _ProductsPickerState();
}

class _ProductsPickerState extends ConsumerState<_ProductsPicker> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value);
    });
  }

  Product _placeholder(String id) => Product(
        id: id,
        storeId: '',
        categoryId: '',
        name: '(sản phẩm đã xoá)',
        slug: '',
        description: '',
        basePrice: 0,
        images: const [],
        variants: const [],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final results = ref.watch(_pickerResultsProvider(_query));

    return _Section(
      title: 'Sản phẩm trong bộ sưu tập',
      children: [
        if (widget.selectedIds.isNotEmpty) ...[
          Text(
            'Đã chọn ${widget.selectedIds.length} · kéo tay cầm để sắp xếp.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: BananSpacing.sm),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: widget.onReorder,
            children: [
              for (final id in widget.selectedIds)
                _SelectedRow(
                  key: ValueKey(id),
                  product: widget.productById[id] ?? _placeholder(id),
                  fmt: fmt,
                  onRemove: () => widget.onRemove(id),
                ),
            ],
          ),
          const Divider(height: BananSpacing.xl),
        ],
        TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Tìm món để thêm…',
            suffixIcon: _searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Xoá tìm kiếm',
                    onPressed: () {
                      _debounce?.cancel();
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: BananSpacing.md),
        results.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(BananSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Text(
            'Không tải được danh sách món.',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          data: (products) {
            if (products.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: BananSpacing.md),
                child: Text(
                  _query.trim().isEmpty
                      ? 'Chưa có sản phẩm nào.'
                      : 'Không tìm thấy “${_query.trim()}”.',
                  style: theme.textTheme.bodySmall,
                ),
              );
            }
            return Column(
              children: [
                for (final p in products)
                  _ResultRow(
                    product: p,
                    fmt: fmt,
                    selected: widget.selectedIds.contains(p.id),
                    onTap: () => widget.onToggle(p),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A single search-result row: thumbnail + name + price, with a trailing
/// add/added toggle. Tapping anywhere toggles membership.
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.product,
    required this.fmt,
    required this.selected,
    required this.onTap,
  });

  final Product product;
  final NumberFormat fmt;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _Thumb(url: product.coverImage),
      title: Text(
        product.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('từ ${fmt.format(product.minPrice)}'),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.add_circle_outline,
        color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
      onTap: onTap,
    );
  }
}

/// 44×44 rounded thumbnail with graceful fallbacks for missing/broken images.
class _Thumb extends StatelessWidget {
  const _Thumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.cake_outlined, size: 20),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: url == null || url!.isEmpty
            ? fallback
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _SelectedRow extends StatelessWidget {
  const _SelectedRow({
    required this.product,
    required this.fmt,
    required this.onRemove,
    super.key,
  });

  final Product product;
  final NumberFormat fmt;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BananSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: BananSpacing.md,
          vertical: BananSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rmd,
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Row(
          children: [
            const Icon(Icons.drag_handle),
            const SizedBox(width: BananSpacing.sm),
            _Thumb(url: product.coverImage),
            const SizedBox(width: BananSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: theme.textTheme.titleSmall),
                  Text(
                    'từ ${fmt.format(product.minPrice)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Xoá',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

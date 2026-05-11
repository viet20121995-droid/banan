import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/cover_image_picker.dart';
import '../menu_mgmt/menu_list_screen.dart';
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
        title: Text(widget.isEditing ? 'Edit collection' : 'New collection'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => context.pop(),
            child: const Text('Cancel'),
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
            label: const Text('Save'),
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
                      title: 'Basics',
                      children: [
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
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
                          decoration: const InputDecoration(
                            labelText: 'URL slug',
                            helperText: 'lowercase, dashes, unique per store',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: BananSpacing.md),
                        TextFormField(
                          controller: _description,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                            helperText:
                                'Shown under the title on the customer home',
                          ),
                        ),
                        const SizedBox(height: BananSpacing.lg),
                        CoverImagePicker(
                          url: _coverUrl,
                          onChanged: (url) =>
                              setState(() => _coverUrl = url),
                          helperText:
                              'Shown as the carousel banner on the customer home.',
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Visibility',
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Pin to customer home'),
                          subtitle: const Text(
                            'Pinned collections show as horizontal '
                            'carousels on the menu screen.',
                          ),
                          value: _isPinnedToHome,
                          onChanged: (v) =>
                              setState(() => _isPinnedToHome = v),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active'),
                          subtitle: const Text(
                            'Inactive collections are hidden from customers '
                            'but kept here for re-use later.',
                          ),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                        const SizedBox(height: BananSpacing.sm),
                        Row(
                          children: [
                            const SizedBox(width: BananSpacing.xs),
                            const Text('Sort order'),
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
                      onChanged: (ids) =>
                          setState(() => _selectedProductIds
                            ..clear()
                            ..addAll(ids),),
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

class _ProductsPicker extends ConsumerWidget {
  const _ProductsPicker({
    required this.selectedIds,
    required this.onChanged,
  });

  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(merchantMenuControllerProvider);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final theme = Theme.of(context);

    return _Section(
      title: 'Products in this collection',
      children: [
        if (state.loading && state.products.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (state.products.isEmpty)
          const Text("You haven't created any products yet.")
        else ...[
          Text(
            '${selectedIds.length} selected · tap to toggle, drag the handles to reorder.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: BananSpacing.md),
          if (selectedIds.isNotEmpty) ...[
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: true,
              onReorder: (oldIndex, newIndex) {
                final ids = [...selectedIds];
                final item = ids.removeAt(oldIndex);
                ids.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
                onChanged(ids);
              },
              children: [
                for (final id in selectedIds)
                  _SelectedRow(
                    key: ValueKey(id),
                    product: state.products.firstWhere(
                      (p) => p.id == id,
                      orElse: () => Product(
                        id: id,
                        storeId: '',
                        categoryId: '',
                        name: '(deleted product)',
                        slug: '',
                        description: '',
                        basePrice: 0,
                        images: const [],
                        variants: const [],
                      ),
                    ),
                    fmt: fmt,
                    onRemove: () =>
                        onChanged(selectedIds.where((x) => x != id).toList()),
                  ),
              ],
            ),
            const Divider(height: BananSpacing.xl),
          ],
          Text('Available products', style: theme.textTheme.titleSmall),
          const SizedBox(height: BananSpacing.sm),
          Wrap(
            spacing: BananSpacing.sm,
            runSpacing: BananSpacing.sm,
            children: [
              for (final p in state.products)
                FilterChip(
                  label: Text(p.name),
                  selected: selectedIds.contains(p.id),
                  onSelected: (s) {
                    final next = [...selectedIds];
                    if (s) {
                      if (!next.contains(p.id)) next.add(p.id);
                    } else {
                      next.remove(p.id);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
        ],
      ],
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: theme.textTheme.titleSmall),
                  Text(
                    'from ${fmt.format(product.minPrice)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

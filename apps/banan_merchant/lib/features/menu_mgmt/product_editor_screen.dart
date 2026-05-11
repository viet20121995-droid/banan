import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'menu_list_screen.dart';

/// Loads a product for editing. Family parameter = product id.
final _editorProductProvider = FutureProvider.autoDispose
    .family<Product, String>((ref, id) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final res = await repo.product(id);
  return res.when(
    success: (p) => p,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

class ProductEditorScreen extends ConsumerStatefulWidget {
  const ProductEditorScreen({this.productId, super.key});

  /// Null = create flow. Non-null = edit existing product.
  final String? productId;

  bool get isEditing => productId != null;

  @override
  ConsumerState<ProductEditorScreen> createState() =>
      _ProductEditorScreenState();
}

class _ProductEditorScreenState extends ConsumerState<ProductEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _description;
  late final TextEditingController _basePrice;
  late final TextEditingController _prep;
  String? _categoryId;
  bool _available = true;
  bool _seasonal = false;
  List<String> _images = [];
  List<String> _tags = [];
  List<VariantDraft> _variants = [VariantDraft(size: '6"', flavor: 'Classic')];
  bool _saving = false;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _slug = TextEditingController();
    _description = TextEditingController();
    _basePrice = TextEditingController(text: '0');
    _prep = TextEditingController(text: '60');
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    _basePrice.dispose();
    _prep.dispose();
    super.dispose();
  }

  void _hydrateFrom(Product p) {
    if (_initialized) return;
    _initialized = true;
    _name.text = p.name;
    _slug.text = p.slug;
    _description.text = p.description;
    _basePrice.text = p.basePrice.toStringAsFixed(0);
    _prep.text = p.preparationMinutes.toString();
    _categoryId = p.categoryId;
    _available = p.isAvailable;
    _seasonal = p.isSeasonal;
    _images = List.of(p.images);
    _tags = List.of(p.tags);
    _variants = p.variants
        .map(
          (v) => VariantDraft(
            id: v.id,
            size: v.size,
            flavor: v.flavor,
            priceDelta: v.priceDelta,
            stockQty: v.stockQty,
            isAvailable: v.isAvailable,
          ),
        )
        .toList();
    setState(() {});
  }

  Future<void> _pickImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    final repo = ref.read(catalogRepositoryProvider);
    setState(() => _saving = true);
    final result = await repo.uploadImage(
      bytes: file.bytes!,
      filename: file.name,
      mimeType: _mimeFor(file.extension),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (uploaded) {
        setState(() => _images = [..._images, uploaded.url]);
      },
      failure: (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${authFailureMessage(f)}')),
        );
      },
    );
  }

  String _mimeFor(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'avif':
        return 'image/avif';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _error = 'Please pick a category.');
      return;
    }
    if (_variants.isEmpty) {
      setState(() => _error = 'At least one variant is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = ProductDraft(
      categoryId: _categoryId!,
      name: _name.text.trim(),
      slug: _slug.text.trim(),
      description: _description.text.trim(),
      basePrice: double.tryParse(_basePrice.text) ?? 0,
      images: _images,
      tags: _tags,
      variants: _variants,
      preparationMinutes: int.tryParse(_prep.text),
      isAvailable: _available,
      isSeasonal: _seasonal,
    );

    final repo = ref.read(catalogRepositoryProvider);
    final result = widget.isEditing
        ? await repo.updateProduct(widget.productId!, draft)
        : await repo.createProduct(draft);

    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      success: (_) {
        ref.invalidate(merchantMenuControllerProvider);
        context.pop();
      },
      failure: (f) {
        setState(() => _error = authFailureMessage(f));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    if (widget.isEditing && !_initialized) {
      final productAsync = ref.watch(_editorProductProvider(widget.productId!));
      return productAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          body: ErrorState(message: e.toString()),
        ),
        data: (p) {
          // Hydrate after the first frame to avoid setState-in-build.
          WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFrom(p));
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit product' : 'New product'),
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
                        margin: const EdgeInsets.only(bottom: BananSpacing.lg),
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
                            helperText: 'Lowercase, dashes, unique per store',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: BananSpacing.md),
                        TextFormField(
                          controller: _description,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(labelText: 'Description'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: BananSpacing.md),
                        categoriesAsync.when(
                          loading: () =>
                              const LinearProgressIndicator(minHeight: 2),
                          error: (e, _) =>
                              Text('Could not load categories: $e'),
                          data: (categories) => DropdownButtonFormField<String>(
                            initialValue: _categoryId,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _categoryId = v),
                          ),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Pricing & timing',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _basePrice,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Base price (₫)',
                                ),
                                validator: (v) {
                                  final n = double.tryParse(v ?? '');
                                  if (n == null || n < 0) {
                                    return 'Enter a valid price';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: BananSpacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: _prep,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Prep time (min)',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: BananSpacing.md),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Available to customers'),
                          value: _available,
                          onChanged: (v) => setState(() => _available = v),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Seasonal'),
                          value: _seasonal,
                          onChanged: (v) => setState(() => _seasonal = v),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Photos',
                      action: TextButton.icon(
                        onPressed: _saving ? null : _pickImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Upload photo'),
                      ),
                      children: [
                        if (_images.isEmpty)
                          const Text(
                            'No photos yet. The first photo becomes the cover.',
                          )
                        else
                          Wrap(
                            spacing: BananSpacing.sm,
                            runSpacing: BananSpacing.sm,
                            children: _images
                                .map(
                                  (url) => _Thumb(
                                    url: url,
                                    onRemove: () => setState(
                                      () => _images = _images
                                          .where((x) => x != url)
                                          .toList(),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                    _Section(
                      title: 'Tags',
                      children: [
                        Text(
                          'Free-form badges shown on the customer card. '
                          'Examples: Vegan, Bestseller, Gluten-free.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: BananSpacing.md),
                        _TagsInput(
                          tags: _tags,
                          onChanged: (next) => setState(() => _tags = next),
                        ),
                      ],
                    ),
                    _VariantsSection(
                      variants: _variants,
                      onChanged: (vs) => setState(() => _variants = vs),
                    ),
                    const SizedBox(height: BananSpacing.xxxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _slugify(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.action,
  });

  final String title;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: BananSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.onRemove});
  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BananRadii.rmd,
          child: SizedBox(
            width: 96,
            height: 96,
            child: Image.network(url, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            shape: const CircleBorder(),
            color: Colors.black54,
            child: IconButton(
              iconSize: 16,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onRemove,
            ),
          ),
        ),
      ],
    );
  }
}

class _TagsInput extends StatefulWidget {
  const _TagsInput({required this.tags, required this.onChanged});
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_TagsInput> createState() => _TagsInputState();
}

class _TagsInputState extends State<_TagsInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return;
    if (widget.tags.contains(v)) return;
    if (widget.tags.length >= 8) return;
    widget.onChanged([...widget.tags, v]);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.tags.isNotEmpty) ...[
          Wrap(
            spacing: BananSpacing.sm,
            runSpacing: BananSpacing.sm,
            children: [
              for (final tag in widget.tags)
                InputChip(
                  label: Text(tag),
                  onDeleted: () => widget.onChanged(
                    widget.tags.where((t) => t != tag).toList(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: BananSpacing.md),
        ],
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Add a tag',
            hintText: widget.tags.length >= 8
                ? 'Maximum 8 tags'
                : 'Type and press Enter',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: widget.tags.length >= 8
                  ? null
                  : () => _add(_controller.text),
            ),
          ),
          enabled: widget.tags.length < 8,
          textInputAction: TextInputAction.done,
          onSubmitted: _add,
        ),
      ],
    );
  }
}

class _VariantsSection extends StatelessWidget {
  const _VariantsSection({required this.variants, required this.onChanged});

  final List<VariantDraft> variants;
  final ValueChanged<List<VariantDraft>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Variants',
      action: TextButton.icon(
        onPressed: () => onChanged(
          [
            ...variants,
            VariantDraft(size: '', flavor: ''),
          ],
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add variant'),
      ),
      children: [
        for (var i = 0; i < variants.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: BananSpacing.sm),
            child: _VariantRow(
              key: ValueKey(variants[i].id ?? 'new-$i'),
              variant: variants[i],
              onRemove: variants.length == 1
                  ? null
                  : () => onChanged(
                        [...variants]..removeAt(i),
                      ),
            ),
          ),
      ],
    );
  }
}

class _VariantRow extends StatefulWidget {
  const _VariantRow({required this.variant, this.onRemove, super.key});

  final VariantDraft variant;
  final VoidCallback? onRemove;

  @override
  State<_VariantRow> createState() => _VariantRowState();
}

class _VariantRowState extends State<_VariantRow> {
  late final TextEditingController _size =
      TextEditingController(text: widget.variant.size);
  late final TextEditingController _flavor =
      TextEditingController(text: widget.variant.flavor);
  late final TextEditingController _delta = TextEditingController(
    text: widget.variant.priceDelta.toStringAsFixed(0),
  );

  @override
  void dispose() {
    _size.dispose();
    _flavor.dispose();
    _delta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _size,
            decoration: const InputDecoration(labelText: 'Size'),
            onChanged: (v) => widget.variant.size = v,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ),
        const SizedBox(width: BananSpacing.sm),
        Expanded(
          child: TextFormField(
            controller: _flavor,
            decoration: const InputDecoration(labelText: 'Flavor'),
            onChanged: (v) => widget.variant.flavor = v,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ),
        const SizedBox(width: BananSpacing.sm),
        SizedBox(
          width: 140,
          child: TextFormField(
            controller: _delta,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Δ price (₫)',
              helperText: '+ over base',
            ),
            onChanged: (v) =>
                widget.variant.priceDelta = double.tryParse(v) ?? 0,
          ),
        ),
        if (widget.onRemove != null)
          Padding(
            padding: const EdgeInsets.only(top: BananSpacing.sm),
            child: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: widget.onRemove,
            ),
          ),
      ],
    );
  }
}

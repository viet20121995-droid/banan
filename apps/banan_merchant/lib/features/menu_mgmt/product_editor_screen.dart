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
  late final TextEditingController _leadHours;
  late final TextEditingController _dailyMax;
  late final TextEditingController _flavorPick;
  String? _categoryId;
  bool _available = true;
  bool _seasonal = false;
  /// 0=Sun..6=Sat. Empty = every day (no restriction).
  List<int> _availableDow = [];
  List<String> _images = [];
  List<String> _tags = [];
  /// Macaron flavour-composer options. Empty = composer off.
  List<String> _flavorOptions = [];
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
    _leadHours = TextEditingController();
    _dailyMax = TextEditingController();
    _flavorPick = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    _basePrice.dispose();
    _prep.dispose();
    _leadHours.dispose();
    _dailyMax.dispose();
    _flavorPick.dispose();
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
    _leadHours.text = p.leadTimeHours?.toString() ?? '';
    _dailyMax.text = p.dailyMaxQuantity?.toString() ?? '';
    _availableDow = List.of(p.availableDaysOfWeek);
    _images = List.of(p.images);
    _tags = List.of(p.tags);
    _flavorPick.text = p.flavorPickCount?.toString() ?? '';
    _flavorOptions = List.of(p.flavorOptions);
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
          SnackBar(content: Text('Tải ảnh thất bại: ${authFailureMessage(f)}')),
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
      setState(() => _error = 'Vui lòng chọn danh mục.');
      return;
    }
    if (_variants.isEmpty) {
      setState(() => _error = 'Cần ít nhất một biến thể.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final leadRaw = _leadHours.text.trim();
    final dailyRaw = _dailyMax.text.trim();
    final flavorPickRaw = _flavorPick.text.trim();
    // 0 / empty = composer off. When off we send flavorPickCount = null (NOT 0):
    // the backend DTO is @Min(2), so a 0 would 400 the whole save. Options are
    // only carried when the composer is on.
    final flavorPick = flavorPickRaw.isEmpty ? 0 : int.tryParse(flavorPickRaw) ?? 0;
    final composerOn = flavorPick > 0 && _flavorOptions.isNotEmpty;
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
      leadTimeHours: leadRaw.isEmpty ? null : int.tryParse(leadRaw),
      availableDaysOfWeek: List.of(_availableDow)..sort(),
      dailyMaxQuantity: dailyRaw.isEmpty ? null : int.tryParse(dailyRaw),
      // null (not 0) when the composer is off, so the @Min(2) backend rule is
      // skipped (@IsOptional). A count is only sent for a real macaron set.
      flavorPickCount: composerOn ? flavorPick : null,
      flavorOptions: composerOn ? List.of(_flavorOptions) : const [],
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
        title: Text(widget.isEditing ? 'Sửa sản phẩm' : 'Sản phẩm mới'),
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
                            helperText: 'Chữ thường, gạch nối, duy nhất trong cửa hàng',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Bắt buộc'
                              : null,
                        ),
                        const SizedBox(height: BananSpacing.md),
                        TextFormField(
                          controller: _description,
                          maxLines: 4,
                          maxLength: 1000,
                          decoration:
                              const InputDecoration(labelText: 'Mô tả'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Bắt buộc'
                              : null,
                        ),
                        const SizedBox(height: BananSpacing.md),
                        categoriesAsync.when(
                          loading: () =>
                              const LinearProgressIndicator(minHeight: 2),
                          error: (e, _) =>
                              Text('Không tải được danh mục: $e'),
                          data: (categories) => DropdownButtonFormField<String>(
                            initialValue: _categoryId,
                            decoration: const InputDecoration(
                              labelText: 'Danh mục',
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
                      title: 'Giá & thời gian',
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
                                  labelText: 'Giá gốc (₫)',
                                ),
                                validator: (v) {
                                  final n = double.tryParse(v ?? '');
                                  if (n == null || n < 0) {
                                    return 'Nhập giá hợp lệ';
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
                                  labelText: 'Thời gian làm (phút)',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: BananSpacing.md),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Hiển thị cho khách'),
                          value: _available,
                          onChanged: (v) => setState(() => _available = v),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Theo mùa'),
                          value: _seasonal,
                          onChanged: (v) => setState(() => _seasonal = v),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Hình ảnh',
                      action: TextButton.icon(
                        onPressed: _saving ? null : _pickImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Tải ảnh'),
                      ),
                      children: [
                        Text(
                          'Khuyến nghị: ảnh vuông 1200×1200px (tỉ lệ 1:1), '
                          'bánh nằm giữa khung, nền sáng  ·  ≤ 8 MB/ảnh '
                          '(server tối đa 20 MB)  ·  JPG / PNG / WebP / AVIF',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: BananSpacing.sm),
                        if (_images.isEmpty)
                          const Text(
                            'Chưa có ảnh. Ảnh đầu tiên sẽ làm ảnh bìa.',
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
                      title: 'Nhãn',
                      children: [
                        Text(
                          'Nhãn tự do hiển thị trên thẻ sản phẩm khách thấy. '
                          'Ví dụ: Thuần chay, Bán chạy, Không gluten.',
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
                    _Section(
                      title: 'Khả dụng & quy tắc đặt hàng',
                      children: [
                        Text(
                          'Tuỳ chọn, bỏ trống nếu sản phẩm bán bình thường '
                          'mọi ngày và dùng quy tắc chung của cửa hàng.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: BananSpacing.md),
                        TextFormField(
                          controller: _leadHours,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Thời gian báo trước (giờ)',
                            helperText:
                                'Khách phải đặt trước ít nhất số giờ này. '
                                'Bỏ trống = dùng mặc định của cửa hàng.',
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return null;
                            final n = int.tryParse(t);
                            if (n == null || n < 0 || n > 720) {
                              return 'Nhập số giờ từ 0 đến 720';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: BananSpacing.md),
                        TextFormField(
                          controller: _dailyMax,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Số lượng tối đa mỗi ngày',
                            helperText:
                                'Bỏ trống = không giới hạn. Khi đạt mức này, '
                                'sản phẩm sẽ tự ẩn cho đến ngày hôm sau.',
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return null;
                            final n = int.tryParse(t);
                            if (n == null || n < 1) {
                              return 'Nhập số nguyên ≥ 1';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: BananSpacing.md),
                        Text(
                          'Ngày trong tuần nhận đơn',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: BananSpacing.xs),
                        Text(
                          'Bỏ chọn tất cả = bán mọi ngày.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: BananSpacing.sm),
                        _DowChips(
                          selected: _availableDow,
                          onChanged: (next) =>
                              setState(() => _availableDow = next),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Chọn vị (macaron)',
                      children: [
                        Text(
                          'Dành cho set macaron / bánh nhiều vị. Khách sẽ chọn '
                          'đúng số vị bên dưới từ danh sách vị có sẵn trước khi '
                          'thêm vào giỏ. Để 0 (hoặc bỏ trống) nếu sản phẩm '
                          'thường, không có chọn vị.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: BananSpacing.md),
                        TextFormField(
                          controller: _flavorPick,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Số vị khách phải chọn',
                            helperText:
                                '0 = tắt chọn vị. Ví dụ set 6 macaron → nhập 6.',
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return null; // trống = tắt
                            final n = int.tryParse(t);
                            if (n == null || n < 0) {
                              return 'Nhập số nguyên ≥ 0';
                            }
                            // Backend yêu cầu ≥ 2 (set nhiều vị). 0 = tắt; 1 vô nghĩa.
                            if (n == 1) {
                              return 'Nhập 0 để tắt, hoặc từ 2 trở lên';
                            }
                            if (n >= 2 && _flavorOptions.isEmpty) {
                              return 'Đã đặt số vị, hãy thêm danh sách vị bên dưới';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: BananSpacing.md),
                        Text(
                          'Danh sách vị',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: BananSpacing.xs),
                        _FlavorOptionsInput(
                          options: _flavorOptions,
                          onChanged: (next) =>
                              setState(() => _flavorOptions = next),
                        ),
                      ],
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

  /// Curated quick-add chips for a Japanese-inspired patisserie. Grouped so
  /// the merchant taps instead of typing — keeps wording consistent across
  /// the whole menu (important: the customer filters/searches on these).
  static const _dietary = <(String, IconData)>[
    ('Không gluten', Icons.spa_outlined),
    ('Thuần chay', Icons.eco_outlined),
    ('Không sữa', Icons.no_drinks_outlined),
    ('Không trứng', Icons.egg_alt_outlined),
    ('Không hạt', Icons.health_and_safety_outlined),
    ('Không đường', Icons.icecream_outlined),
    ('Ít ngọt', Icons.cake_outlined),
    ('Halal', Icons.verified_outlined),
    ('Hữu cơ', Icons.grass_outlined),
  ];
  static const _highlight = <(String, IconData)>[
    ('Bán chạy', Icons.local_fire_department_outlined),
    ('Mới', Icons.fiber_new_outlined),
    ('Đầu bếp gợi ý', Icons.star_outline),
    ('Giới hạn', Icons.timelapse_outlined),
  ];

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

  void _toggle(String tag) {
    if (widget.tags.contains(tag)) {
      widget.onChanged(widget.tags.where((t) => t != tag).toList());
    } else if (widget.tags.length < 8) {
      widget.onChanged([...widget.tags, tag]);
    }
  }

  Widget _presetGroup(String title, List<(String, IconData)> presets) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.outline,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: BananSpacing.xs),
        Wrap(
          spacing: BananSpacing.sm,
          runSpacing: BananSpacing.sm,
          children: [
            for (final (label, icon) in presets)
              FilterChip(
                avatar: Icon(icon, size: 16),
                label: Text(label),
                selected: widget.tags.contains(label),
                onSelected: (_) => _toggle(label),
              ),
          ],
        ),
        const SizedBox(height: BananSpacing.md),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Custom tags = whatever isn't in the preset lists (free-typed extras).
    final presetLabels = {
      ..._dietary.map((e) => e.$1),
      ..._highlight.map((e) => e.$1),
    };
    final customTags =
        widget.tags.where((t) => !presetLabels.contains(t)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _presetGroup('CHẾ ĐỘ ĂN & DỊ ỨNG', _dietary),
        _presetGroup('ĐIỂM NỔI BẬT', _highlight),
        if (customTags.isNotEmpty) ...[
          Text(
            'TUỲ CHỈNH',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  letterSpacing: 0.4,
                ),
          ),
          const SizedBox(height: BananSpacing.xs),
          Wrap(
            spacing: BananSpacing.sm,
            runSpacing: BananSpacing.sm,
            children: [
              for (final tag in customTags)
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
            labelText: 'Thêm nhãn tuỳ chỉnh',
            helperText:
                'Đã dùng ${widget.tags.length}/8 · chạm chip ở trên hoặc tự nhập',
            hintText: widget.tags.length >= 8
                ? 'Tối đa 8 nhãn'
                : 'vd. Matcha, Đặt trước',
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

/// Editable list of macaron flavour names — chips + an add field. Mirrors the
/// custom-tag input pattern. Duplicates are ignored; order is preserved.
class _FlavorOptionsInput extends StatefulWidget {
  const _FlavorOptionsInput({required this.options, required this.onChanged});

  final List<String> options;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_FlavorOptionsInput> createState() => _FlavorOptionsInputState();
}

class _FlavorOptionsInputState extends State<_FlavorOptionsInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return;
    if (widget.options.contains(v)) {
      _controller.clear();
      return;
    }
    widget.onChanged([...widget.options, v]);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.options.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: BananSpacing.sm),
            child: Text(
              'Chưa có vị nào. Thêm các vị như "Trà xanh", "Socola", "Dâu"…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: BananSpacing.sm),
            child: Wrap(
              spacing: BananSpacing.sm,
              runSpacing: BananSpacing.sm,
              children: [
                for (final f in widget.options)
                  InputChip(
                    label: Text(f),
                    onDeleted: () => widget.onChanged(
                      widget.options.where((x) => x != f).toList(),
                    ),
                  ),
              ],
            ),
          ),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Thêm vị',
            hintText: 'vd. Trà xanh, Socola',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _add(_controller.text),
            ),
          ),
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
      title: 'Biến thể',
      action: TextButton.icon(
        onPressed: () => onChanged(
          [
            ...variants,
            VariantDraft(size: '', flavor: ''),
          ],
        ),
        icon: const Icon(Icons.add),
        label: const Text('Thêm biến thể'),
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
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Kích cỡ'),
            onChanged: (v) => widget.variant.size = v,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Bắt buộc' : null,
          ),
        ),
        const SizedBox(width: BananSpacing.sm),
        Expanded(
          child: TextFormField(
            controller: _flavor,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Hương vị'),
            onChanged: (v) => widget.variant.flavor = v,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Bắt buộc' : null,
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
              labelText: 'Δ giá (₫)',
              helperText: '+ so với giá gốc',
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

/// Multi-select chips for days-of-week. JS-style indexing (0=CN..6=T7).
class _DowChips extends StatelessWidget {
  const _DowChips({required this.selected, required this.onChanged});

  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  static const _days = <(int dow, String label)>[
    (1, 'T2'),
    (2, 'T3'),
    (3, 'T4'),
    (4, 'T5'),
    (5, 'T6'),
    (6, 'T7'),
    (0, 'CN'),
  ];

  void _toggle(int dow) {
    final next = [...selected];
    if (next.contains(dow)) {
      next.remove(dow);
    } else {
      next.add(dow);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: BananSpacing.sm,
      runSpacing: BananSpacing.sm,
      children: [
        for (final d in _days)
          FilterChip(
            label: Text(d.$2),
            selected: selected.contains(d.$1),
            onSelected: (_) => _toggle(d.$1),
          ),
      ],
    );
  }
}

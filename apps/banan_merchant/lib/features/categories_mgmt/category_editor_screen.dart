import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/cover_image_picker.dart';
import 'categories_list_screen.dart';

/// Loads the single category being edited. The list provider already holds the
/// full set, so we read it from there rather than firing a fresh request —
/// the categories endpoint has no per-id GET.
final _editorCategoryProvider =
    FutureProvider.autoDispose.family<Category, String>((ref, id) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final res = await repo.categories();
  return res.when(
    success: (list) => list.firstWhere(
      (c) => c.id == id,
      orElse: () => throw Exception('Không tìm thấy danh mục.'),
    ),
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

class CategoryEditorScreen extends ConsumerStatefulWidget {
  const CategoryEditorScreen({this.categoryId, super.key});

  final String? categoryId;
  bool get isEditing => categoryId != null;

  @override
  ConsumerState<CategoryEditorScreen> createState() =>
      _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends ConsumerState<CategoryEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  String? _coverUrl;
  bool _isPinnedToHome = false;
  bool _isBirthdayCakeCategory = false;
  int _sortOrder = 0;

  bool _saving = false;
  bool _initialized = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    super.dispose();
  }

  void _hydrateFrom(Category c) {
    if (_initialized) return;
    _initialized = true;
    _name.text = c.name;
    _slug.text = c.slug;
    _coverUrl = c.imageUrl;
    _isPinnedToHome = c.isPinnedToHome;
    _isBirthdayCakeCategory = c.isBirthdayCakeCategory;
    _sortOrder = c.sortOrder;
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = CategoryDraft(
      name: _name.text.trim(),
      slug: _slug.text.trim(),
      imageUrl: _coverUrl,
      isPinnedToHome: _isPinnedToHome,
      isBirthdayCakeCategory: _isBirthdayCakeCategory,
      sortOrder: _sortOrder,
    );

    final repo = ref.read(catalogRepositoryProvider);
    final result = widget.isEditing
        ? await repo.updateCategory(widget.categoryId!, draft)
        : await repo.createCategory(draft);

    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) {
        ref.invalidate(categoriesControllerProvider);
        context.pop();
      },
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing && !_initialized) {
      final async = ref.watch(_editorCategoryProvider(widget.categoryId!));
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
        title: Text(widget.isEditing ? 'Sửa danh mục' : 'Tạo danh mục'),
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
                          maxLength: 80,
                          decoration: const InputDecoration(labelText: 'Tên'),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Bắt buộc';
                            if (t.length > 80) return 'Tối đa 80 ký tự';
                            return null;
                          },
                          onChanged: (v) {
                            if (_slug.text.isEmpty) {
                              _slug.text = _slugify(v);
                            }
                          },
                        ),
                        const SizedBox(height: BananSpacing.md),
                        TextFormField(
                          controller: _slug,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Slug URL',
                            helperText:
                                'chữ thường, dấu gạch, duy nhất toàn hệ thống',
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Bắt buộc';
                            if (t.length > 80) return 'Tối đa 80 ký tự';
                            return null;
                          },
                        ),
                        const SizedBox(height: BananSpacing.lg),
                        CoverImagePicker(
                          url: _coverUrl,
                          helperText:
                              'Ảnh đại diện danh mục (tuỳ chọn).',
                          recommendedSize: '800×800px (tỉ lệ 1:1)',
                          onChanged: (url) => setState(() => _coverUrl = url),
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
                            'Danh mục được ghim sẽ hiện thành dải sản phẩm '
                            'ngang trên màn hình thực đơn của khách.',
                          ),
                          value: _isPinnedToHome,
                          onChanged: (v) =>
                              setState(() => _isPinnedToHome = v),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Đây là danh mục Bánh sinh nhật'),
                          subtitle: const Text(
                            'Chỉ một danh mục được đặt làm danh mục Bánh sinh '
                            'nhật. Sản phẩm trong danh mục này sẽ có trình '
                            'tuỳ chỉnh bánh (cake personalization wizard) ở '
                            'trang chi tiết của khách.',
                          ),
                          value: _isBirthdayCakeCategory,
                          onChanged: (v) =>
                              setState(() => _isBirthdayCakeCategory = v),
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

  String _slugify(String s) => _foldVietnamese(s)
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// Folds Vietnamese diacritics to plain ASCII so slugs come out as
  /// "banh-kem" instead of "b-nh-kem". Covers all tone/vowel marks plus đ/Đ.
  static String _foldVietnamese(String s) {
    const map = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    final buf = StringBuffer();
    for (final ch in s.runes) {
      final c = String.fromCharCode(ch);
      final lower = c.toLowerCase();
      String? base;
      for (final entry in map.entries) {
        if (entry.value.contains(lower)) {
          base = entry.key;
          break;
        }
      }
      if (base == null) {
        buf.write(c);
      } else {
        // Preserve original case (uppercase variants fold the same way).
        buf.write(c == lower ? base : base.toUpperCase());
      }
    }
    return buf.toString();
  }
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

import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart' as domain;
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/gallery_image_picker.dart';
import 'threads_list_screen.dart';

final _editorThreadProvider = FutureProvider.autoDispose
    .family<domain.Thread, String>((ref, id) async {
  final repo = ref.watch(threadsRepositoryProvider);
  final res = await repo.get(id);
  return res.when(
    success: (t) => t,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

/// Merchant's own products — for the optional "Shop this" link.
final _pickerProductsProvider =
    FutureProvider.autoDispose<List<domain.Product>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final res = await repo.merchantProducts(perPage: 100);
  return res.when(
    success: (page) => page.items,
    failure: (_) => const <domain.Product>[],
  );
});

class ThreadEditorScreen extends ConsumerStatefulWidget {
  const ThreadEditorScreen({this.threadId, super.key});

  final String? threadId;
  bool get isEditing => threadId != null;

  @override
  ConsumerState<ThreadEditorScreen> createState() =>
      _ThreadEditorScreenState();
}

class _ThreadEditorScreenState extends ConsumerState<ThreadEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _ctaLabel = TextEditingController();
  final _ctaUrl = TextEditingController();
  List<String> _images = [];
  String? _productId;
  DateTime? _scheduledAt;
  bool _publish = false;
  bool _saving = false;
  bool _initialized = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _ctaLabel.dispose();
    _ctaUrl.dispose();
    super.dispose();
  }

  void _hydrateFrom(domain.Thread t) {
    if (_initialized) return;
    _initialized = true;
    _title.text = t.title;
    _body.text = t.body;
    _ctaLabel.text = t.ctaLabel ?? '';
    _ctaUrl.text = t.ctaUrl ?? '';
    _images = t.gallery;
    _productId = t.productId;
    _scheduledAt = t.scheduledPublishAt;
    _publish = t.isPublished;
    setState(() {});
  }

  List<String> get _previewHashtags {
    final re = RegExp(r'#[\p{L}0-9_]+', unicode: true);
    final seen = <String>{};
    for (final m in re.allMatches(_body.text)) {
      seen.add(m.group(0)!.toLowerCase());
      if (seen.length >= 15) break;
    }
    return seen.toList();
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
      _publish = publish;
    });
    final draft = domain.ThreadDraft(
      title: _title.text.trim(),
      body: _body.text.trim(),
      imageUrl: _images.isNotEmpty ? _images.first : null,
      images: _images,
      productId: _productId,
      ctaLabel: _ctaLabel.text.trim().isEmpty ? null : _ctaLabel.text.trim(),
      ctaUrl: _ctaUrl.text.trim().isEmpty ? null : _ctaUrl.text.trim(),
      scheduledPublishAt: (!publish && _scheduledAt != null)
          ? _scheduledAt
          : null,
      publish: publish,
    );
    final repo = ref.read(threadsRepositoryProvider);
    final res = widget.isEditing
        ? await repo.update(widget.threadId!, draft)
        : await repo.create(draft);
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        ref.invalidate(threadsControllerProvider);
        context.pop();
      },
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing && !_initialized) {
      final async = ref.watch(_editorThreadProvider(widget.threadId!));
      return async.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(body: ErrorState(message: e.toString())),
        data: (t) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFrom(t));
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    final theme = Theme.of(context);
    final tags = _previewHashtags;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Sửa bài đăng' : 'Bài đăng mới'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => context.pop(),
            child: const Text('Huỷ'),
          ),
          OutlinedButton(
            onPressed: _saving ? null : () => _save(publish: false),
            child: Text(_scheduledAt != null ? 'Lưu & lên lịch' : 'Lưu nháp'),
          ),
          const SizedBox(width: BananSpacing.sm),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(publish: true),
            icon: _saving && _publish
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish_outlined),
            label: Text(widget.isEditing && _publish ? 'Cập nhật' : 'Đăng'),
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
                constraints: const BoxConstraints(maxWidth: 720),
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
                          color: theme.colorScheme.errorContainer
                              .withValues(alpha: 0.4),
                        ),
                        child: Text(_error!),
                      ),
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề',
                        helperText: 'Tối đa 140 ký tự',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                    ),
                    const SizedBox(height: BananSpacing.lg),
                    GalleryImagePicker(
                      urls: _images,
                      onChanged: (next) => setState(() => _images = next),
                    ),
                    const SizedBox(height: BananSpacing.lg),
                    TextFormField(
                      controller: _body,
                      maxLines: 10,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Nội dung',
                        helperText:
                            'Dùng #hashtag trong nội dung, chúng sẽ trở thành '
                            'bộ lọc bấm được trên feed khách hàng.',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: BananSpacing.sm),
                      Wrap(
                        spacing: BananSpacing.xs,
                        runSpacing: BananSpacing.xs,
                        children: [
                          for (final t in tags)
                            Chip(
                              label: Text(t),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: BananSpacing.xl),
                    Text('Mua sản phẩm này',
                        style: theme.textTheme.titleSmall,),
                    const SizedBox(height: BananSpacing.xs),
                    Text(
                      'Tuỳ chọn, liên kết bài đăng với một sản phẩm của bạn.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: BananSpacing.sm),
                    _ProductPicker(
                      selectedId: _productId,
                      onChanged: (id) => setState(() => _productId = id),
                    ),
                    const SizedBox(height: BananSpacing.xl),
                    Text('Nút kêu gọi hành động',
                        style: theme.textTheme.titleSmall,),
                    const SizedBox(height: BananSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ctaLabel,
                            maxLength: 40,
                            decoration: const InputDecoration(
                              labelText: 'Nhãn nút',
                              hintText: 'Đặt ngay',
                            ),
                          ),
                        ),
                        const SizedBox(width: BananSpacing.md),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _ctaUrl,
                            maxLength: 300,
                            decoration: const InputDecoration(
                              labelText: 'Liên kết nút (URL)',
                              hintText: 'https://…',
                            ),
                            validator: (v) {
                              final s = v?.trim() ?? '';
                              if (s.isEmpty) return null;
                              final ok = Uri.tryParse(s)?.hasAbsolutePath ??
                                  false;
                              return ok ? null : 'Nhập URL hợp lệ';
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: BananSpacing.xl),
                    Text('Lên lịch', style: theme.textTheme.titleSmall),
                    const SizedBox(height: BananSpacing.xs),
                    Text(
                      'Lưu nháp với thời gian trong tương lai, hệ thống sẽ '
                      'tự đăng đúng giờ đó. Bấm "Đăng" ngay sẽ bỏ qua lịch hẹn.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: BananSpacing.sm),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickSchedule,
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(
                            _scheduledAt == null
                                ? 'Chọn thời gian đăng'
                                : _fmt(_scheduledAt!),
                          ),
                        ),
                        if (_scheduledAt != null) ...[
                          const SizedBox(width: BananSpacing.sm),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _scheduledAt = null),
                            icon: const Icon(Icons.close),
                            label: const Text('Xoá lịch'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }
}

class _ProductPicker extends ConsumerWidget {
  const _ProductPicker({required this.selectedId, required this.onChanged});

  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_pickerProductsProvider);
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Không tải được sản phẩm.'),
      data: (products) {
        final ids = products.map((p) => p.id).toSet();
        final value = ids.contains(selectedId) ? selectedId : null;
        return DropdownButtonFormField<String?>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Sản phẩm liên kết',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Không có'),
            ),
            for (final p in products)
              DropdownMenuItem<String?>(
                value: p.id,
                child: Text(p.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

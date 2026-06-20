import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'kitchens_list_screen.dart';

/// Loads the single kitchen being edited from the list (no per-id GET).
final _editorKitchenProvider =
    FutureProvider.autoDispose.family<Kitchen, String>((ref, id) async {
  final repo = ref.watch(kitchensRepositoryProvider);
  final res = await repo.list();
  return res.when(
    success: (list) => list.firstWhere(
      (k) => k.id == id,
      orElse: () => throw Exception('Không tìm thấy bếp.'),
    ),
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

class KitchenEditorScreen extends ConsumerStatefulWidget {
  const KitchenEditorScreen({this.kitchenId, super.key});

  final String? kitchenId;
  bool get isEditing => kitchenId != null;

  @override
  ConsumerState<KitchenEditorScreen> createState() =>
      _KitchenEditorScreenState();
}

class _KitchenEditorScreenState extends ConsumerState<KitchenEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _capacity = TextEditingController(text: '40');

  bool _saving = false;
  bool _initialized = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _capacity.dispose();
    super.dispose();
  }

  void _hydrateFrom(Kitchen k) {
    if (_initialized) return;
    _initialized = true;
    _name.text = k.name;
    _address.text = k.address;
    _capacity.text = '${k.capacityPerHour}';
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = KitchenDraft(
      name: _name.text.trim(),
      address: _address.text.trim(),
      capacityPerHour: int.tryParse(_capacity.text.trim()) ?? 40,
    );

    final repo = ref.read(kitchensRepositoryProvider);
    final result = widget.isEditing
        ? await repo.update(widget.kitchenId!, draft)
        : await repo.create(draft);

    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) {
        ref
          ..invalidate(kitchensControllerProvider)
          // Refresh the store editor's default-kitchen picker too.
          ..invalidate(kitchensListProvider);
        context.pop();
      },
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing && !_initialized) {
      final async = ref.watch(_editorKitchenProvider(widget.kitchenId!));
      return async.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(body: ErrorState(message: e.toString())),
        data: (k) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFrom(k));
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Sửa bếp' : 'Tạo bếp'),
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
                    TextFormField(
                      controller: _name,
                      maxLength: 120,
                      decoration: const InputDecoration(labelText: 'Tên bếp'),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Bắt buộc' : null,
                    ),
                    const SizedBox(height: BananSpacing.md),
                    TextFormField(
                      controller: _address,
                      maxLength: 255,
                      decoration: const InputDecoration(labelText: 'Địa chỉ'),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Bắt buộc' : null,
                    ),
                    const SizedBox(height: BananSpacing.md),
                    TextFormField(
                      controller: _capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Công suất (đơn/giờ)',
                        helperText:
                            'Giới hạn mềm dùng cho bộ lập kế hoạch sản xuất.',
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n < 1) return 'Nhập số ≥ 1';
                        return null;
                      },
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
}

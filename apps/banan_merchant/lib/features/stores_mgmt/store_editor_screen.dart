import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'stores_list_screen.dart';

/// Loads the single store being edited from the admin list (no per-id GET).
final _editorStoreProvider =
    FutureProvider.autoDispose.family<Store, String>((ref, id) async {
  final repo = ref.watch(storesRepositoryProvider);
  final res = await repo.listForAdmin();
  return res.when(
    success: (list) => list.firstWhere(
      (s) => s.id == id,
      orElse: () => throw Exception('Không tìm thấy cửa hàng.'),
    ),
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

class StoreEditorScreen extends ConsumerStatefulWidget {
  const StoreEditorScreen({this.storeId, super.key});

  final String? storeId;
  bool get isEditing => storeId != null;

  @override
  ConsumerState<StoreEditorScreen> createState() => _StoreEditorScreenState();
}

class _StoreEditorScreenState extends ConsumerState<StoreEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _ward = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  String? _defaultKitchenId;

  bool _saving = false;
  bool _initialized = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _address.dispose();
    _phone.dispose();
    _ward.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _hydrateFrom(Store s) {
    if (_initialized) return;
    _initialized = true;
    _name.text = s.name;
    _slug.text = s.slug;
    _address.text = s.address;
    _phone.text = s.phone;
    _ward.text = s.wardCode ?? '';
    _lat.text = s.lat?.toString() ?? '';
    _lng.text = s.lng?.toString() ?? '';
    _defaultKitchenId = s.defaultKitchenId;
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = StoreDraft(
      name: _name.text.trim(),
      slug: _slug.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      wardCode: _ward.text.trim(),
      defaultKitchenId: _defaultKitchenId,
      lat: double.tryParse(_lat.text.trim()),
      lng: double.tryParse(_lng.text.trim()),
    );

    final repo = ref.read(storesRepositoryProvider);
    final result = widget.isEditing
        ? await repo.update(widget.storeId!, draft)
        : await repo.create(draft);

    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) {
        ref.invalidate(storesControllerProvider);
        context.pop();
      },
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing && !_initialized) {
      final async = ref.watch(_editorStoreProvider(widget.storeId!));
      return async.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(body: ErrorState(message: e.toString())),
        data: (s) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFrom(s));
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Sửa cửa hàng' : 'Tạo cửa hàng'),
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
                          decoration:
                              const InputDecoration(labelText: 'Tên cửa hàng'),
                          validator: _required,
                          onChanged: (v) {
                            if (_slug.text.isEmpty) _slug.text = _slugify(v);
                          },
                        ),
                        const SizedBox(height: BananSpacing.md),
                        TextFormField(
                          controller: _slug,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Slug URL',
                            helperText:
                                'chữ thường, dấu gạch, duy nhất toàn hệ thống',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: BananSpacing.md),
                        TextFormField(
                          controller: _address,
                          maxLength: 255,
                          decoration:
                              const InputDecoration(labelText: 'Địa chỉ'),
                          validator: _required,
                        ),
                        const SizedBox(height: BananSpacing.md),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại',
                          ),
                          validator: _required,
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Định tuyến & giao hàng',
                      children: [
                        _buildKitchenDropdown(),
                        const SizedBox(height: BananSpacing.md),
                        TextFormField(
                          controller: _ward,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Mã phường (tuỳ chọn)',
                            helperText:
                                'Slug phường tại TP.HCM, quyết định phí giao '
                                'cùng phường / khác phường. Để trống nếu chưa rõ.',
                          ),
                        ),
                        const SizedBox(height: BananSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _lat,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Vĩ độ (lat)',
                                ),
                                validator: _optionalNumber,
                              ),
                            ),
                            const SizedBox(width: BananSpacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: _lng,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Kinh độ (lng)',
                                ),
                                validator: _optionalNumber,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (!widget.isEditing)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: BananSpacing.lg),
                        child: Text(
                          'Giờ mở cửa, tạm nghỉ, đơn tối thiểu… sẽ đặt mặc định '
                          'và tinh chỉnh sau ở mục "Cửa hàng" (cài đặt vận hành).',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
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

  Widget _buildKitchenDropdown() {
    final async = ref.watch(kitchensListProvider);
    return async.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(labelText: 'Bếp phụ trách'),
        child: SizedBox(
          height: 24,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, __) => const Text(
        'Không tải được danh sách bếp.',
      ),
      data: (kitchens) {
        final ids = kitchens.map((k) => k.id).toSet();
        // Drop a stale reference (e.g. the kitchen was deleted).
        final value = ids.contains(_defaultKitchenId) ? _defaultKitchenId : null;
        return DropdownButtonFormField<String?>(
          initialValue: value,
          decoration: const InputDecoration(
            labelText: 'Bếp phụ trách (mặc định)',
            helperText: 'Bếp chuẩn bị đơn cho chi nhánh này.',
          ),
          items: [
            const DropdownMenuItem<String?>(
              child: Text('Chưa gán'),
            ),
            for (final k in kitchens)
              DropdownMenuItem<String?>(value: k.id, child: Text(k.name)),
          ],
          onChanged: (v) => setState(() => _defaultKitchenId = v),
        );
      },
    );
  }

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? 'Bắt buộc' : null;

  String? _optionalNumber(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return double.tryParse(t) == null ? 'Số không hợp lệ' : null;
  }

  String _slugify(String s) => _foldVietnamese(s)
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// Folds Vietnamese diacritics to plain ASCII so slugs come out as
  /// "cua-hang-q1" instead of "c-a-h-ng-q1".
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

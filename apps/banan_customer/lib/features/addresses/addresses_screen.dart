import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The signed-in customer's saved delivery addresses.
final myAddressesProvider =
    FutureProvider.autoDispose<List<Address>>((ref) async {
  final res = await ref.watch(addressesRepositoryProvider).list();
  return res.when(
    success: (list) => list,
    failure: (f) => throw Exception(authFailureMessage(f)),
  );
});

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAddressesProvider);
    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.myAddresses)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref, null),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(s.addAddress),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(myAddressesProvider),
        ),
        data: (addresses) {
          if (addresses.isEmpty) {
            return EmptyState(
              title: s.noAddressesTitle,
              message: s.noAddressesMsg,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myAddressesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  BananSpacing.lg, BananSpacing.lg, BananSpacing.lg, 96,),
              itemCount: addresses.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: BananSpacing.md),
              itemBuilder: (_, i) => _AddressCard(
                address: addresses[i],
                onEdit: () => _openEditor(context, ref, addresses[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    Address? initial,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddressEditorSheet(initial: initial),
    );
    if (saved ?? false) ref.invalidate(myAddressesProvider);
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.address, required this.onEdit});
  final Address address;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(
          color: address.isDefault
              ? BananColors.gold
              : theme.dividerTheme.color ?? Colors.black12,
          width: address.isDefault ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 18, color: theme.colorScheme.primary,),
              const SizedBox(width: BananSpacing.xs),
              Text(address.label, style: theme.textTheme.titleSmall),
              if (address.isDefault) ...[
                const SizedBox(width: BananSpacing.sm),
                _DefaultBadge(label: s.defaultBadge),
              ],
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'edit':
                      onEdit();
                    case 'default':
                      await ref
                          .read(addressesRepositoryProvider)
                          .setDefault(address.id);
                      ref.invalidate(myAddressesProvider);
                    case 'delete':
                      final ok = await _confirmDelete(context, s);
                      if (ok) {
                        await ref
                            .read(addressesRepositoryProvider)
                            .delete(address.id);
                        ref.invalidate(myAddressesProvider);
                      }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(s.edit)),
                  if (!address.isDefault)
                    PopupMenuItem(
                      value: 'default',
                      child: Text(s.setDefault),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(s.delete),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.xs),
          Text(address.recipient, style: theme.textTheme.bodyMedium),
          Text(address.phone, style: theme.textTheme.bodySmall),
          const SizedBox(height: BananSpacing.xs),
          Text(address.oneLine, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, AppStrings s) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteAddressQ),
        content: Text(s.cannotUndo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    return r ?? false;
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: BananColors.gold,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600,),
      ),
    );
  }
}

class _AddressEditorSheet extends ConsumerStatefulWidget {
  const _AddressEditorSheet({this.initial});
  final Address? initial;

  @override
  ConsumerState<_AddressEditorSheet> createState() =>
      _AddressEditorSheetState();
}

class _AddressEditorSheetState extends ConsumerState<_AddressEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _recipient;
  late final TextEditingController _phone;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _postal;
  /// Selected HCMC ward code from the catalog dropdown (post-2025 reform).
  String? _wardCode;
  bool _isDefault = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    _label = TextEditingController(text: a?.label ?? 'Home');
    _recipient = TextEditingController(text: a?.recipient ?? '');
    _phone = TextEditingController(text: a?.phone ?? '');
    _line1 = TextEditingController(text: a?.line1 ?? '');
    _line2 = TextEditingController(text: a?.line2 ?? '');
    _city = TextEditingController(text: 'Thành phố Hồ Chí Minh');
    _district = TextEditingController(text: a?.district ?? '');
    _postal = TextEditingController(text: a?.postalCode ?? '');
    _wardCode = a?.wardCode;
    _isDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _label.dispose();
    _recipient.dispose();
    _phone.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _district.dispose();
    _postal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = AddressDraft(
      label: _label.text.trim(),
      recipient: _recipient.text.trim(),
      phone: _phone.text.trim(),
      line1: _line1.text.trim(),
      line2: _line2.text.trim().isEmpty ? null : _line2.text.trim(),
      city: _city.text.trim(),
      district:
          _district.text.trim().isEmpty ? null : _district.text.trim(),
      wardCode: _wardCode,
      postalCode:
          _postal.text.trim().isEmpty ? null : _postal.text.trim(),
      isDefault: _isDefault,
    );
    final repo = ref.read(addressesRepositoryProvider);
    final res = _isEditing
        ? await repo.update(widget.initial!.id, draft)
        : await repo.create(draft);
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) => Navigator.pop(context, true),
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          BananSpacing.lg, 0, BananSpacing.lg, bottom + BananSpacing.lg,),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              _isEditing ? s.editAddress : s.newAddress,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: BananSpacing.md),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(BananSpacing.md),
                margin: const EdgeInsets.only(bottom: BananSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BananRadii.rmd,
                  color: theme.colorScheme.errorContainer
                      .withValues(alpha: 0.4),
                ),
                child: Text(_error!),
              ),
            _field(s, _label, s.labelFieldHint, req: true),
            _field(s, _recipient, s.recipientName, req: true),
            _field(s, _phone, s.phone, req: true,
                keyboard: TextInputType.phone,),
            _field(s, _line1, s.addressLine, req: true),
            _field(s, _line2, s.apartmentOptional),
            // Locked — Banan chỉ giao trong TP.HCM.
            Padding(
              padding: const EdgeInsets.only(bottom: BananSpacing.sm),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: s.city,
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  enabled: false,
                  helperText: 'Banan hiện chỉ giao trong TP.HCM',
                ),
                child: Text(
                  'Thành phố Hồ Chí Minh',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            // Post-2025 reform: HCMC removed districts; addresses are now
            // identified by ward (phường/xã). The picker reads the catalog
            // from the server so the list stays current without a redeploy.
            _WardPicker(
              selectedCode: _wardCode,
              onChanged: (code) => setState(() => _wardCode = code),
            ),
            _field(s, _district, s.districtOptional),
            _field(s, _postal, s.postalOptional),
            const SizedBox(height: BananSpacing.xs),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.setAsDefaultAddress),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
            ),
            const SizedBox(height: BananSpacing.sm),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isEditing ? s.saveChanges : s.addAddress),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    AppStrings s,
    TextEditingController c,
    String label, {
    bool req = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.sm),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
        validator: req
            ? (v) =>
                (v == null || v.trim().isEmpty) ? s.required : null
            : null,
      ),
    );
  }
}

/// Searchable ward picker for HCMC (post-2025 admin reform). Sources from
/// `hcmWardsProvider`. Customers can type to filter by ward name or by the
/// pre-reform district hint (e.g. typing "Q1" surfaces all old-District-1
/// wards). Saves the selected ward's `code` to the form.
class _WardPicker extends ConsumerWidget {
  const _WardPicker({required this.selectedCode, required this.onChanged});
  final String? selectedCode;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hcmWardsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.sm),
      child: async.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => TextFormField(
          enabled: false,
          decoration: InputDecoration(
            labelText: 'Phường (TP.HCM)',
            errorText: 'Không tải được danh sách phường',
          ),
        ),
        data: (wards) {
          final selected =
              wards.cast<HcmWard?>().firstWhere(
                    (w) => w?.code == selectedCode,
                    orElse: () => null,
                  );
          return InkWell(
            onTap: () async {
              final picked = await showModalBottomSheet<HcmWard?>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _WardPickerSheet(wards: wards),
              );
              if (picked != null) onChanged(picked.code);
            },
            borderRadius: BananRadii.rmd,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Phường (TP.HCM)',
                helperText: 'Sau cải cách 7/2025 — chọn phường thay cho quận',
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              child: Text(
                selected?.name ?? 'Chọn phường…',
                style: selected == null
                    ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        )
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bottom-sheet ward picker with a search field. Filters by name and by the
/// pre-reform district hint, so customers used to the old "Q1" / "Bình
/// Thạnh" labels can still find their ward quickly.
class _WardPickerSheet extends StatefulWidget {
  const _WardPickerSheet({required this.wards});
  final List<HcmWard> wards;

  @override
  State<_WardPickerSheet> createState() => _WardPickerSheetState();
}

class _WardPickerSheetState extends State<_WardPickerSheet> {
  final _query = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lower = _q.trim().toLowerCase();
    final filtered = lower.isEmpty
        ? widget.wards
        : widget.wards.where((w) {
            return w.name.toLowerCase().contains(lower) ||
                (w.oldArea ?? '').toLowerCase().contains(lower);
          }).toList();
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, scrollCtrl) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: BananSpacing.lg),
        child: Column(
          children: [
            Text(
              'Chọn phường (TP.HCM)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: BananSpacing.sm),
            TextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên phường hoặc quận cũ',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: BananSpacing.sm),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Không tìm thấy phường khớp.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final w = filtered[i];
                        return ListTile(
                          title: Text(w.name),
                          subtitle: w.oldArea == null
                              ? null
                              : Text('Quận/khu vực cũ: ${w.oldArea}'),
                          onTap: () => Navigator.pop(context, w),
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

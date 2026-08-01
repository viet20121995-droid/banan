import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single ward picker shared by the address book and the checkout form —
/// one implementation so search/sort/labels never drift between the two.
///
/// Renders an [InputDecorator] that opens a searchable bottom sheet over the
/// 102-unit former-HCMC delivery catalog (post-01/07/2025). The backend
/// retains all 168 current administrative units, while customer delivery is
/// intentionally restricted to the pre-merger TP.HCM footprint. Search is
/// diacritic-insensitive and matches the new ward name AND the pre-reform
/// area hint, including the "Q12" shorthand (see [wardMatchesQuery]).
///
/// A saved address may still carry a pre-reform code (e.g. `cau-kho`) —
/// [HcmWard.matchesCode] resolves it against each ward's `legacyCodes` so
/// the picker shows the ward that absorbed the old one instead of looking
/// unset.
class WardPickerField extends ConsumerWidget {
  const WardPickerField({
    required this.selectedCode,
    required this.onChanged,
    this.errorText,
    this.helperText,
    super.key,
  });

  final String? selectedCode;
  final ValueChanged<String?> onChanged;

  /// Validation error shown under the field (checkout: "chọn phường/xã",
  /// "chưa hỗ trợ giao đến khu vực này").
  final String? errorText;

  /// Optional helper line; defaults to the shared reform hint.
  final String? helperText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hcmWardsProvider);
    final s = ref.watch(stringsProvider);
    return async.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, __) => InputDecorator(
        decoration: InputDecoration(
          labelText: s.wardLabel,
          errorText: s.wardLoadError,
        ),
        child: const Text('—'),
      ),
      data: (wards) {
        final selected = wards.cast<HcmWard?>().firstWhere(
              (w) => w?.matchesCode(selectedCode) ?? false,
              orElse: () => null,
            );
        // A stored code the catalog can no longer resolve (unknown, or a
        // pre-reform ward that was SPLIT and must be re-picked) surfaces
        // its own hint even before submit-time validation runs.
        final effectiveError = errorText ??
            (selectedCode != null && selected == null
                ? s.wardReselectRequired
                : null);
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
            decoration: InputDecoration(
              labelText: s.wardLabel,
              helperText: effectiveError == null
                  ? (helperText ?? s.wardReformHelper)
                  : null,
              errorText: effectiveError,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              selected?.name ?? s.chooseWard,
              style: selected == null
                  ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      )
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      },
    );
  }
}

class _WardPickerSheet extends ConsumerStatefulWidget {
  const _WardPickerSheet({required this.wards});
  final List<HcmWard> wards;

  @override
  ConsumerState<_WardPickerSheet> createState() => _WardPickerSheetState();
}

class _WardPickerSheetState extends ConsumerState<_WardPickerSheet> {
  final _query = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only wards Banan actually delivers to are offered — a ward the
    // customer can never check out with is noise, not choice.
    final filtered = widget.wards
        .where((w) => w.serviceable && wardMatchesQuery(w, _q))
        .toList();
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, scrollCtrl) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: BananSpacing.lg),
        child: Column(
          children: [
            Text(
              s.chooseWardTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: BananSpacing.sm),
            TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                hintText: s.wardSearchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: BananSpacing.sm),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        s.noWardMatch,
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
                              : Text(s.oldAreaLabel(w.oldArea!)),
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

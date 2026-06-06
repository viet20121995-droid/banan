import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../addresses/addresses_screen.dart' show myAddressesProvider;
import '../locations/locations_screen.dart' show storesListProvider;

/// Shared fulfillment widgets used by both the Toast-style cart screen and the
/// checkout screen. Extracted from `checkout_screen.dart` so the cart can
/// reuse the exact same pickup / schedule / saved-address pickers without
/// duplicating their logic. Behaviour is identical to the original private
/// versions — only the visibility (public) changed.

/// Pickup branch selector — radio list of all Banan stores, rendered from
/// the same `storesListProvider` the Locations screen uses. Auto-selects
/// the first branch when the list first loads, so the customer doesn't
/// have to tap anything to use the default.
class PickupStorePicker extends ConsumerStatefulWidget {
  const PickupStorePicker({
    required this.selectedId,
    required this.onSelect,
    super.key,
  });
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  ConsumerState<PickupStorePicker> createState() => _PickupStorePickerState();
}

class _PickupStorePickerState extends ConsumerState<PickupStorePicker> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(storesListProvider);
    final s = ref.watch(stringsProvider);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: BananSpacing.md),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(
        s.couldNotLoadBranches,
        style: theme.textTheme.bodySmall,
      ),
      data: (stores) {
        // Auto-select the first *available* branch the first time we see
        // the list — skipping any that have pickup paused, so the customer
        // never lands on a blocked default. Falls back to the first store
        // if every branch is paused (so the picker still renders something).
        if (widget.selectedId == null && stores.isNotEmpty) {
          final firstOpen = stores.firstWhere(
            (s) => s.acceptsPickup,
            orElse: () => stores.first,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onSelect(firstOpen.id);
          });
        }
        // If the currently selected store gets paused (rare but possible
        // when the page is open while the merchant toggles), bounce to
        // the next available one automatically.
        final sel = widget.selectedId == null
            ? null
            : stores.cast<Store?>().firstWhere(
                  (s) => s?.id == widget.selectedId,
                  orElse: () => null,
                );
        if (sel != null && !sel.acceptsPickup) {
          final next = stores.firstWhere(
            (s) => s.acceptsPickup,
            orElse: () => sel,
          );
          if (next.id != sel.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onSelect(next.id);
            });
          }
        }
        return Column(
          children: [
            for (final store in stores)
              Padding(
                padding: const EdgeInsets.only(bottom: BananSpacing.sm),
                child: _StoreOption(
                  store: store,
                  selected: store.id == widget.selectedId,
                  // Disable selection when this branch isn't accepting
                  // pickup; the badge inside the tile explains why.
                  onTap: store.acceptsPickup
                      ? () => widget.onSelect(store.id)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StoreOption extends StatelessWidget {
  const _StoreOption({
    required this.store,
    required this.selected,
    required this.onTap,
  });

  final Store store;
  final bool selected;

  /// Null = this branch is paused and can't be selected. The tile renders
  /// dimmed with a "Đang tạm nghỉ" badge instead.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BananRadii.rmd,
        child: Container(
          padding: const EdgeInsets.all(BananSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BananRadii.rmd,
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : theme.colorScheme.surface,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : (theme.dividerTheme.color ?? Colors.black12),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                disabled
                    ? Icons.block
                    : (selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off),
                color: disabled
                    ? theme.colorScheme.outline
                    : (selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline),
                size: 22,
              ),
              const SizedBox(width: BananSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            store.name,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: BananSpacing.sm),
                        if (disabled)
                          _PausedChip(reason: store.pauseReason)
                        else
                          _OpenClosedChip(open: store.isOpenNow),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      store.address,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (disabled && (store.pauseReason?.isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          store.pauseReason!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Đang tạm nghỉ" badge shown on a paused branch tile.
class _PausedChip extends StatelessWidget {
  const _PausedChip({this.reason});
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Đang tạm nghỉ',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Tiny green "Open" / grey "Closed" pill.
class _OpenClosedChip extends ConsumerWidget {
  const _OpenClosedChip({required this.open});
  final bool open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = open ? BananColors.success : BananColors.cocoaSoft;
    final t = ref.watch(stringsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rPill,
        color: color.withValues(alpha: 0.14),
      ),
      child: Text(
        open ? t.openNow : t.closedNow,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// "Dùng địa chỉ đã lưu" — lets a signed-in customer pick from their address
/// book to auto-fill the inline delivery form. Default address first.
/// Hidden entirely when the customer has no saved addresses (the loading /
/// error / empty states collapse to nothing so the manual form stays clean).
class SavedAddressPicker extends ConsumerWidget {
  const SavedAddressPicker({
    required this.selectedId,
    required this.onSelect,
    super.key,
  });

  final String? selectedId;
  final ValueChanged<Address> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(myAddressesProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (addresses) {
        if (addresses.isEmpty) return const SizedBox.shrink();
        // Default address first, then the rest in their existing order.
        final sorted = [...addresses]..sort(
            (a, b) => (b.isDefault ? 1 : 0).compareTo(a.isDefault ? 1 : 0),
          );
        return Container(
          padding: const EdgeInsets.all(BananSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BananRadii.rmd,
            color: theme.colorScheme.surface,
            border:
                Border.all(color: theme.dividerTheme.color ?? Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bookmark_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: BananSpacing.sm),
                  Text(
                    'Dùng địa chỉ đã lưu',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: BananSpacing.sm),
              for (final a in sorted)
                Padding(
                  padding: const EdgeInsets.only(bottom: BananSpacing.xs),
                  child: _SavedAddressTile(
                    address: a,
                    selected: a.id == selectedId,
                    onTap: () => onSelect(a),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SavedAddressTile extends StatelessWidget {
  const _SavedAddressTile({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        selected ? theme.colorScheme.primary : theme.colorScheme.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: BananRadii.rmd,
      child: Container(
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rmd,
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.06)
              : theme.colorScheme.surface,
          border: Border.all(color: color, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: color,
            ),
            const SizedBox(width: BananSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          address.label,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: BananSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: BananColors.gold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Mặc định',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${address.recipient} · ${address.phone}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    address.oneLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "As soon as possible" vs "Schedule for later" toggle. When the customer
/// picks a future date+time, [onChanged] fires with the chosen DateTime.
/// Same picker for pickup or delivery — the parent screen relabels above it.
class ScheduleSection extends ConsumerWidget {
  const ScheduleSection({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  static const _minLeadMinutes = 30;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = value ?? now.add(const Duration(hours: 3));
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    // Guard rail: refuse picks too close to now — the store needs lead time.
    final earliest = now.add(const Duration(minutes: _minLeadMinutes));
    onChanged(picked.isBefore(earliest) ? earliest : picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final isScheduled = value != null;
    final fmt = DateFormat.yMMMEd().add_jm();

    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(s.scheduleNow),
                icon: const Icon(Icons.flash_on_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text(s.scheduleLater),
                icon: const Icon(Icons.event_outlined),
              ),
            ],
            selected: {isScheduled},
            onSelectionChanged: (set) {
              if (set.first) {
                _pick(context);
              } else {
                onChanged(null);
              }
            },
          ),
          if (isScheduled) ...[
            const SizedBox(height: BananSpacing.md),
            InkWell(
              onTap: () => _pick(context),
              borderRadius: BananRadii.rmd,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BananSpacing.sm,
                  vertical: BananSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, color: theme.colorScheme.primary),
                    const SizedBox(width: BananSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fmt.format(value!),
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            _relativeLabel(value!, s),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_calendar_outlined),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _relativeLabel(DateTime when, AppStrings s) {
    final diff = when.difference(DateTime.now());
    if (diff.inMinutes < 60) return s.inMinutes(diff.inMinutes);
    if (diff.inHours < 24) return s.inHours(diff.inHours);
    final days = diff.inDays;
    return days == 1 ? s.tomorrow : s.inDays(days);
  }
}

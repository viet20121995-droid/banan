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
        // All branches visible, laid out horizontally: 2 per row on a wide
        // (desktop) column, 1 per row on narrow (mobile) so nothing overflows.
        return LayoutBuilder(
          builder: (context, c) {
            final twoUp = c.maxWidth >= 520;
            final cardW =
                twoUp ? (c.maxWidth - BananSpacing.sm) / 2 : c.maxWidth;
            return Wrap(
              spacing: BananSpacing.sm,
              runSpacing: BananSpacing.sm,
              children: [
                for (final store in stores)
                  SizedBox(
                    width: cardW,
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
      },
    );
  }
}

/// One selectable pickup-branch tile in the horizontal grid. Compact: name +
/// open/closed badge on top, single-line address below.
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
                size: 20,
              ),
              const SizedBox(width: BananSpacing.sm),
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
                          const _PausedChip()
                        else
                          _OpenClosedChip(open: store.isOpenNow),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      store.address,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Why this branch is paused (e.g. "Hết nguyên liệu"), when
                    // the merchant set a reason. Only shown for paused tiles.
                    if (disabled && (store.pauseReason?.isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          store.pauseReason!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
  const _PausedChip();

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

/// The soonest valid slot given a required [lead] from now, rounded up to the
/// next 15-minute boundary so the default looks tidy. When [allowedDays] is set
/// (weekdays 0=Sun..6=Sat the cart can be fulfilled), the slot is advanced to
/// the first allowed day — opening at [openHour] on any day after today — so
/// the default never lands on a day the order would be rejected.
DateTime earliestScheduleSlot(
  Duration lead, {
  Set<int>? allowedDays,
  int openHour = 8,
}) {
  final t = DateTime.now().add(lead);
  final base = DateTime(t.year, t.month, t.day, t.hour);
  final slot = (t.minute / 15).ceil() * 15;
  var earliest = base.add(Duration(minutes: slot));
  if (allowedDays == null || allowedDays.isEmpty || allowedDays.length >= 7) {
    return earliest;
  }
  for (var i = 0; i < 14; i++) {
    if (allowedDays.contains(earliest.weekday % 7)) return earliest;
    final next = DateTime(earliest.year, earliest.month, earliest.day)
        .add(const Duration(days: 1));
    earliest = DateTime(next.year, next.month, next.day, openHour);
  }
  return earliest; // no allowed day within two weeks — fall back gracefully
}

/// Builds the "sold only on certain days" notice, or null when the cart isn't
/// day-restricted. [allowedDays] are weekdays 0=Sun..6=Sat; [names] are the
/// cakes that drive the restriction.
String? dayConstraintNote({
  required List<int> allowedDays,
  required List<String> names,
}) {
  if (allowedDays.isEmpty || allowedDays.length >= 7) return null;
  const wd = {0: 'CN', 1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7'};
  final days =
      (allowedDays.toList()..sort()).map((d) => wd[d] ?? '?$d').join(', ');
  final who = names.isEmpty
      ? 'Một số bánh'
      : (names.length <= 2
          ? names.join(', ')
          : '${names.take(2).join(', ')} và ${names.length - 2} món khác');
  return '$who chỉ bán vào $days, lịch nhận chỉ hiện các ngày này.';
}

/// Builds the "needs preparation time" notice, or null when nothing in the
/// cart requires advance notice. [names] are the cakes that need lead time.
String? prepLeadNote({required int leadHours, required List<String> names}) {
  if (leadHours <= 0) return null;
  final span = (leadHours >= 24 && leadHours % 24 == 0)
      ? '${leadHours ~/ 24} ngày'
      : '$leadHours giờ';
  final who = names.isEmpty
      ? 'Một số bánh'
      : (names.length <= 2
          ? names.join(', ')
          : '${names.take(2).join(', ')} và ${names.length - 2} món khác');
  return '$who cần đặt trước $span để chuẩn bị. Chúng tôi đã chọn sẵn '
      'thời gian nhận sớm nhất. Bạn có thể đổi sang giờ muộn hơn.';
}

/// Wraps [ScheduleSection] with cart-driven lead-time awareness. When the cart
/// has items needing advance notice ([leadHours] > 0) it shows the [leadNote]
/// banner and, once, defaults the schedule to the earliest valid slot so the
/// customer never submits an order the backend would reject for lead time.
class LeadAwareSchedule extends StatefulWidget {
  const LeadAwareSchedule({
    required this.value,
    required this.onChanged,
    required this.leadHours,
    this.leadNote,
    this.allowedDays = const [],
    super.key,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final int leadHours;
  final String? leadNote;

  /// Weekdays (0=Sun..6=Sat) the whole cart can be fulfilled on. Empty / all =
  /// no restriction. Drives both the pre-filled default and the picker.
  final List<int> allowedDays;

  @override
  State<LeadAwareSchedule> createState() => _LeadAwareScheduleState();
}

class _LeadAwareScheduleState extends State<LeadAwareSchedule> {
  Set<int>? get _allowed {
    final a = widget.allowedDays;
    return (a.isEmpty || a.length >= 7) ? null : a.toSet();
  }

  @override
  void initState() {
    super.initState();
    // One-shot: if prep time or a day restriction applies and the customer
    // hasn't chosen a time yet, pre-fill the soonest valid slot.
    final constrained = widget.leadHours > 0 || _allowed != null;
    if (constrained && widget.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.value == null) {
          widget.onChanged(
            earliestScheduleSlot(
              Duration(hours: widget.leadHours),
              allowedDays: _allowed,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScheduleSection(
      value: widget.value,
      onChanged: widget.onChanged,
      minLead: widget.leadHours > 0
          ? Duration(hours: widget.leadHours)
          : const Duration(minutes: 30),
      leadNote: widget.leadNote,
      allowedDays: widget.allowedDays,
    );
  }
}

/// "Soonest" vs "Pick a time" toggle with a friendly day-chip + time-slot
/// picker (replaces the stacked OS date+time dialogs). [minLead] is the
/// soonest valid moment from now; [leadNote] shows an info banner when set.
class ScheduleSection extends ConsumerWidget {
  const ScheduleSection({
    required this.value,
    required this.onChanged,
    this.minLead = const Duration(minutes: 30),
    this.leadNote,
    this.allowedDays = const [],
    super.key,
  });
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final Duration minLead;
  final String? leadNote;

  /// Weekdays (0=Sun..6=Sat) the cart can be fulfilled on. Empty / all = no
  /// restriction; otherwise the picker hides disallowed days.
  final List<int> allowedDays;

  Set<int>? get _allowed =>
      (allowedDays.isEmpty || allowedDays.length >= 7) ? null : allowedDays.toSet();

  Future<void> _pick(BuildContext context) async {
    final earliest = earliestScheduleSlot(minLead, allowedDays: _allowed);
    final initial =
        (value != null && value!.isAfter(earliest)) ? value : earliest;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SchedulePickerSheet(
        earliest: earliest,
        initial: initial,
        allowedDays: _allowed,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final isScheduled = value != null;
    final fmt = DateFormat('HH:mm · dd/MM');
    final earliest = earliestScheduleSlot(minLead, allowedDays: _allowed);

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
          if (leadNote != null) ...[
            _LeadNoteBanner(text: leadNote!),
            const SizedBox(height: BananSpacing.md),
          ],
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
          if (!isScheduled && leadNote != null) ...[
            const SizedBox(height: BananSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: BananSpacing.sm),
                Expanded(
                  child: Text(
                    'Dự kiến sẵn sàng lúc ${fmt.format(earliest)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              ],
            ),
          ],
          if (isScheduled) ...[
            const SizedBox(height: BananSpacing.md),
            InkWell(
              onTap: () => _pick(context),
              borderRadius: BananRadii.rmd,
              child: Container(
                padding: const EdgeInsets.all(BananSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BananRadii.rmd,
                  color: theme.colorScheme.primary.withValues(alpha: 0.06),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
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
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Đổi',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                    const Icon(Icons.chevron_right),
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

/// Amber "needs preparation time" banner shown above the schedule toggle.
class _LeadNoteBanner extends StatelessWidget {
  const _LeadNoteBanner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: BananColors.gold.withValues(alpha: 0.12),
        border: Border.all(color: BananColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.bakery_dining_outlined,
            size: 20,
            color: BananColors.gold,
          ),
          const SizedBox(width: BananSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet day + time-slot picker. Day chips across the next two weeks
/// (Hôm nay / Ngày mai / weekday + date), then 30-minute slots from 08:00 to
/// 20:30, with anything before [earliest] hidden. Much friendlier than the
/// stacked OS date+time dialogs.
class _SchedulePickerSheet extends StatefulWidget {
  const _SchedulePickerSheet({
    required this.earliest,
    this.initial,
    this.allowedDays,
  });
  final DateTime earliest;
  final DateTime? initial;

  /// Weekdays (0=Sun..6=Sat) to keep. Null = every day.
  final Set<int>? allowedDays;
  @override
  State<_SchedulePickerSheet> createState() => _SchedulePickerSheetState();
}

class _SchedulePickerSheetState extends State<_SchedulePickerSheet> {
  static const _openHour = 8;
  static const _closeHour = 20; // last slot 20:30
  late DateTime _day;
  DateTime? _selected;

  bool _isAllowedDay(DateTime d) =>
      widget.allowedDays == null || widget.allowedDays!.contains(d.weekday % 7);

  @override
  void initState() {
    super.initState();
    final candidate = widget.initial ?? widget.earliest;
    // A stale selection on a now-disallowed day falls back to earliest (which
    // the caller already snapped onto an allowed day).
    final init = _isAllowedDay(candidate) ? candidate : widget.earliest;
    _day = DateTime(init.year, init.month, init.day);
    _selected = _isAllowedDay(init) ? init : null;
  }

  List<DateTime> get _days {
    final start = DateTime(
      widget.earliest.year,
      widget.earliest.month,
      widget.earliest.day,
    );
    final all = List.generate(14, (i) => start.add(Duration(days: i)));
    if (widget.allowedDays == null) return all;
    return all.where(_isAllowedDay).toList();
  }

  List<DateTime> _slotsFor(DateTime day) {
    final out = <DateTime>[];
    for (var h = _openHour; h <= _closeHour; h++) {
      for (final m in const [0, 30]) {
        final dt = DateTime(day.year, day.month, day.day, h, m);
        if (!dt.isBefore(widget.earliest)) out.add(dt);
      }
    }
    return out;
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final t0 = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(t0).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Ngày mai';
    const wd = {1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7', 7: 'CN'};
    return '${wd[d.weekday]} ${DateFormat('dd/MM').format(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slots = _slotsFor(_day);
    final hm = DateFormat('HH:mm');
    final full = DateFormat('HH:mm · dd/MM');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BananSpacing.lg,
          0,
          BananSpacing.lg,
          BananSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Chọn giờ nhận', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Sớm nhất: ${full.format(widget.earliest)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: BananSpacing.md),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _days.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: BananSpacing.sm),
                itemBuilder: (_, i) {
                  final d = _days[i];
                  final sel = d.year == _day.year &&
                      d.month == _day.month &&
                      d.day == _day.day;
                  return ChoiceChip(
                    label: Text(_dayLabel(d)),
                    selected: sel,
                    onSelected: (_) => setState(() {
                      _day = DateTime(d.year, d.month, d.day);
                      if (_selected != null &&
                          (_selected!.year != d.year ||
                              _selected!.month != d.month ||
                              _selected!.day != d.day)) {
                        _selected = null;
                      }
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: BananSpacing.md),
            Text('Giờ nhận', style: theme.textTheme.labelLarge),
            const SizedBox(height: BananSpacing.sm),
            if (slots.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: BananSpacing.md),
                child: Text(
                  'Hết khung giờ nhận trong ngày này. Vui lòng chọn ngày khác.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: BananSpacing.sm,
                    runSpacing: BananSpacing.sm,
                    children: [
                      for (final slot in slots)
                        ChoiceChip(
                          label: Text(hm.format(slot)),
                          selected: _selected != null &&
                              _selected!.isAtSameMomentAs(slot),
                          onSelected: (_) =>
                              setState(() => _selected = slot),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: BananSpacing.lg),
            FilledButton.icon(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.pop(context, _selected),
              icon: const Icon(Icons.check),
              label: Text(
                _selected == null
                    ? 'Chọn giờ nhận'
                    : 'Xác nhận ${full.format(_selected!)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:equatable/equatable.dart';

/// A Banan branch — physical location where customers can pick up cakes.
/// Shared `openingHours` JSON shape: each weekday maps to a list of
/// `[open, close]` strings ("HH:mm"), so a closed day is just `[]` and
/// a split shift is two pairs.
class Store extends Equatable {
  const Store({
    required this.id,
    required this.name,
    required this.slug,
    required this.address,
    required this.phone,
    required this.openingHours,
    this.lat,
    this.lng,
    this.wardCode,
    this.defaultKitchenId,
    this.isPaused = false,
    this.isPickupPaused = false,
    this.isDeliveryPaused = false,
    this.pauseReason,
  });

  final String id;
  final String name;
  final String slug;
  final String address;
  final String phone;
  final double? lat;
  final double? lng;

  /// HCMC ward slug this branch sits in (drives same-ward delivery fee).
  /// Null when not yet assigned. Only populated on the admin listing.
  final String? wardCode;

  /// Kitchen that prepares this branch's orders by default. Null when unset.
  /// Only populated on the admin listing.
  final String? defaultKitchenId;

  /// Weekday key (`mon`..`sun`) → list of `[open, close]` time strings.
  final Map<String, List<List<String>>> openingHours;

  /// Master "stop everything" toggle. When true, every channel is paused.
  /// The customer site renders a "Đang tạm nghỉ" banner before checkout.
  final bool isPaused;

  /// Channel-specific pause for in-store pickup orders only.
  final bool isPickupPaused;

  /// Channel-specific pause for delivery orders only.
  final bool isDeliveryPaused;

  /// Merchant-provided reason for the current pause — shown to customers.
  final String? pauseReason;

  /// Whether *this branch* still accepts new pickup orders.
  bool get acceptsPickup => !isPaused && !isPickupPaused;

  /// Whether *this branch* still accepts new delivery orders.
  bool get acceptsDelivery => !isPaused && !isDeliveryPaused;

  /// Whether the branch is open at the given moment (defaults to now).
  /// Times are compared in Vietnam local time (UTC+7, no DST) to match
  /// the backend's enforcement.
  bool isOpenAt([DateTime? when]) {
    final nowUtc = (when ?? DateTime.now()).toUtc();
    final vn = nowUtc.add(const Duration(hours: 7));
    const dayKeys = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
    final key = dayKeys[vn.weekday % 7]; // Dart: Mon=1..Sun=7
    final minutes = vn.hour * 60 + vn.minute;
    final spans = openingHours[key] ?? const [];
    int toMin(String hhmm) {
      final p = hhmm.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    return spans.any((s) => minutes >= toMin(s[0]) && minutes <= toMin(s[1]));
  }

  bool get isOpenNow => isOpenAt();

  /// Friendly summary like
  /// "Mon-Thu: 10:00 AM – 9:30 PM · Fri-Sun: 10:00 AM – 10:00 PM".
  /// Groups consecutive days with identical hours.
  String get hoursSummary {
    final weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    const labels = {
      'mon': 'Mon',
      'tue': 'Tue',
      'wed': 'Wed',
      'thu': 'Thu',
      'fri': 'Fri',
      'sat': 'Sat',
      'sun': 'Sun',
    };
    String slot(String day) {
      final spans = openingHours[day] ?? const [];
      if (spans.isEmpty) return 'Closed';
      return spans
          .map((s) => '${_friendlyTime(s[0])} – ${_friendlyTime(s[1])}')
          .join(', ');
    }

    final groups = <(String, String, String)>[]; // (firstDay, lastDay, slot)
    for (final d in weekdays) {
      final s = slot(d);
      if (groups.isNotEmpty && groups.last.$3 == s) {
        groups[groups.length - 1] =
            (groups.last.$1, d, s);
      } else {
        groups.add((d, d, s));
      }
    }
    return groups
        .map((g) => g.$1 == g.$2
            ? '${labels[g.$1]}: ${g.$3}'
            : '${labels[g.$1]}-${labels[g.$2]}: ${g.$3}',)
        .join(' · ');
  }

  /// "10:00" → "10:00 AM"; "21:30" → "9:30 PM".
  static String _friendlyTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $ampm';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        address,
        phone,
        lat,
        lng,
        wardCode,
        defaultKitchenId,
        openingHours,
        isPaused,
        isPickupPaused,
        isDeliveryPaused,
        pauseReason,
      ];
}

/// Settings panel shape: everything the merchant can tune.
class StoreSettings extends Equatable {
  const StoreSettings({
    required this.id,
    required this.name,
    required this.openingHours,
    required this.isPaused,
    required this.isPickupPaused,
    required this.isDeliveryPaused,
    required this.minOrderVnd,
    required this.defaultLeadHours,
    required this.preparationLeadMinutes,
    this.pauseReason,
  });

  final String id;
  final String name;
  final Map<String, List<List<String>>> openingHours;

  /// Master pause — blocks every order.
  final bool isPaused;

  /// Channel-specific pauses — blocks PICKUP / DELIVERY independently.
  final bool isPickupPaused;
  final bool isDeliveryPaused;

  final String? pauseReason;
  final int minOrderVnd;

  /// Minimum advance notice (in hours) the store requires across all
  /// products. Per-product `leadTimeHours` overrides this.
  final int defaultLeadHours;

  /// Existing scheduler field — how early in the prep cycle to surface
  /// scheduled orders to staff. Exposed here so the settings screen can
  /// show it next to the lead time.
  final int preparationLeadMinutes;

  @override
  List<Object?> get props => [
        id,
        name,
        openingHours,
        isPaused,
        isPickupPaused,
        isDeliveryPaused,
        pauseReason,
        minOrderVnd,
        defaultLeadHours,
        preparationLeadMinutes,
      ];
}

/// A single blackout date (full-day closure).
class StoreBlackoutDate extends Equatable {
  const StoreBlackoutDate({
    required this.id,
    required this.date,
    this.reason,
  });

  final String id;

  /// Closed calendar date (date-only — time component is unused).
  final DateTime date;
  final String? reason;

  @override
  List<Object?> get props => [id, date, reason];
}

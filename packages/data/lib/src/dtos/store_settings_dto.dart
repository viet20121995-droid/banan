import 'package:banan_domain/banan_domain.dart';

import 'store_dto.dart' show parseOpeningHoursJson;

class StoreSettingsDto {
  StoreSettingsDto({
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

  factory StoreSettingsDto.fromJson(Map<String, dynamic> json) {
    return StoreSettingsDto(
      id: json['id'] as String,
      name: json['name'] as String,
      openingHours: parseOpeningHoursJson(json['openingHours']),
      isPaused: json['isPaused'] as bool? ?? false,
      isPickupPaused: json['isPickupPaused'] as bool? ?? false,
      isDeliveryPaused: json['isDeliveryPaused'] as bool? ?? false,
      pauseReason: json['pauseReason'] as String?,
      minOrderVnd: (json['minOrderVnd'] as num?)?.toInt() ?? 0,
      defaultLeadHours: (json['defaultLeadHours'] as num?)?.toInt() ?? 0,
      preparationLeadMinutes:
          (json['preparationLeadMinutes'] as num?)?.toInt() ?? 120,
    );
  }

  final String id;
  final String name;
  final Map<String, List<List<String>>> openingHours;
  final bool isPaused;
  final bool isPickupPaused;
  final bool isDeliveryPaused;
  final String? pauseReason;
  final int minOrderVnd;
  final int defaultLeadHours;
  final int preparationLeadMinutes;

  StoreSettings toDomain() => StoreSettings(
        id: id,
        name: name,
        openingHours: openingHours,
        isPaused: isPaused,
        isPickupPaused: isPickupPaused,
        isDeliveryPaused: isDeliveryPaused,
        pauseReason: pauseReason,
        minOrderVnd: minOrderVnd,
        defaultLeadHours: defaultLeadHours,
        preparationLeadMinutes: preparationLeadMinutes,
      );
}

class StoreBlackoutDateDto {
  StoreBlackoutDateDto({
    required this.id,
    required this.date,
    this.reason,
  });

  factory StoreBlackoutDateDto.fromJson(Map<String, dynamic> json) {
    return StoreBlackoutDateDto(
      id: json['id'] as String,
      // Backend returns full ISO timestamp; we use date-only on the client.
      date: DateTime.parse(json['date'] as String),
      reason: json['reason'] as String?,
    );
  }

  final String id;
  final DateTime date;
  final String? reason;

  StoreBlackoutDate toDomain() => StoreBlackoutDate(
        id: id,
        date: DateTime.utc(date.year, date.month, date.day),
        reason: reason,
      );
}

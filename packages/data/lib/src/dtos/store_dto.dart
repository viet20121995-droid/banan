import 'package:banan_domain/banan_domain.dart';

/// Wire shape returned by `GET /api/v1/stores`.
class StoreDto {
  StoreDto({
    required this.id,
    required this.name,
    required this.slug,
    required this.address,
    required this.phone,
    required this.openingHours,
    this.lat,
    this.lng,
    this.isPaused = false,
    this.isPickupPaused = false,
    this.isDeliveryPaused = false,
    this.pauseReason,
  });

  factory StoreDto.fromJson(Map<String, dynamic> json) {
    return StoreDto(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      openingHours: parseOpeningHoursJson(json['openingHours']),
      isPaused: json['isPaused'] as bool? ?? false,
      isPickupPaused: json['isPickupPaused'] as bool? ?? false,
      isDeliveryPaused: json['isDeliveryPaused'] as bool? ?? false,
      pauseReason: json['pauseReason'] as String?,
    );
  }

  final String id;
  final String name;
  final String slug;
  final String address;
  final String phone;
  final double? lat;
  final double? lng;
  final Map<String, List<List<String>>> openingHours;
  final bool isPaused;
  final bool isPickupPaused;
  final bool isDeliveryPaused;
  final String? pauseReason;

  Store toDomain() => Store(
        id: id,
        name: name,
        slug: slug,
        address: address,
        phone: phone,
        lat: lat,
        lng: lng,
        openingHours: openingHours,
        isPaused: isPaused,
        isPickupPaused: isPickupPaused,
        isDeliveryPaused: isDeliveryPaused,
        pauseReason: pauseReason,
      );
}

/// Shared parser — used by StoreDto and StoreSettingsDto (same JSON shape).
Map<String, List<List<String>>> parseOpeningHoursJson(Object? raw) {
  final hours = <String, List<List<String>>>{};
  if (raw is Map) {
    for (final entry in raw.entries) {
      final day = entry.key.toString();
      final spans = <List<String>>[];
      final list = entry.value;
      if (list is List) {
        for (final span in list) {
          if (span is List && span.length == 2) {
            spans.add([span[0].toString(), span[1].toString()]);
          }
        }
      }
      hours[day] = spans;
    }
  }
  return hours;
}

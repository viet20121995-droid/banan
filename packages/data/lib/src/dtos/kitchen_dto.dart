import 'package:banan_domain/banan_domain.dart';

/// Wire shape returned by the `/admin/kitchens` endpoints.
class KitchenDto {
  const KitchenDto({
    required this.id,
    required this.name,
    required this.address,
    this.capacityPerHour = 40,
  });

  factory KitchenDto.fromJson(Map<String, dynamic> json) => KitchenDto(
        id: json['id'] as String,
        name: json['name'] as String,
        address: (json['address'] as String?) ?? '',
        capacityPerHour: (json['capacityPerHour'] as num?)?.toInt() ?? 40,
      );

  final String id;
  final String name;
  final String address;
  final int capacityPerHour;

  Kitchen toDomain() => Kitchen(
        id: id,
        name: name,
        address: address,
        capacityPerHour: capacityPerHour,
      );
}

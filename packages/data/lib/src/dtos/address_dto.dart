import 'package:banan_domain/banan_domain.dart';

class AddressDto {
  const AddressDto({
    required this.id,
    required this.label,
    required this.recipient,
    required this.phone,
    required this.line1,
    required this.city,
    this.line2,
    this.district,
    this.isDefault = false,
  });

  factory AddressDto.fromJson(Map<String, dynamic> json) {
    return AddressDto(
      id: json['id'] as String,
      label: json['label'] as String? ?? 'Delivery',
      recipient: json['recipient'] as String,
      phone: json['phone'] as String,
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      city: json['city'] as String,
      district: json['district'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  final String id;
  final String label;
  final String recipient;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String? district;
  final bool isDefault;

  Address toDomain() => Address(
        id: id,
        label: label,
        recipient: recipient,
        phone: phone,
        line1: line1,
        line2: line2,
        city: city,
        district: district,
        isDefault: isDefault,
      );
}

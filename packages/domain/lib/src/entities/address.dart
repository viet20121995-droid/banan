import 'package:equatable/equatable.dart';

class Address extends Equatable {
  const Address({
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

  final String id;
  final String label;
  final String recipient;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String? district;
  final bool isDefault;

  String get oneLine {
    final parts = <String>[
      line1,
      if (line2 != null && line2!.isNotEmpty) line2!,
      if (district != null && district!.isNotEmpty) district!,
      city,
    ];
    return parts.join(', ');
  }

  @override
  List<Object?> get props =>
      [id, label, recipient, phone, line1, line2, city, district, isDefault];
}

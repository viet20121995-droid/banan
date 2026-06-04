import 'package:banan_core/banan_core.dart';

import '../entities/address.dart';

/// Payload for creating / updating a saved address.
class AddressDraft {
  const AddressDraft({
    required this.label,
    required this.recipient,
    required this.phone,
    required this.line1,
    required this.city,
    this.line2,
    this.district,
    this.wardCode,
    this.postalCode,
    this.isDefault = false,
  });

  final String label;
  final String recipient;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String? district;

  /// HCMC ward catalog code — post-2025 admin reform.
  final String? wardCode;

  final String? postalCode;
  final bool isDefault;

  Map<String, dynamic> toJson() => {
        'label': label,
        'recipient': recipient,
        'phone': phone,
        'line1': line1,
        'city': city,
        if (line2 != null && line2!.isNotEmpty) 'line2': line2,
        if (district != null && district!.isNotEmpty) 'district': district,
        if (wardCode != null && wardCode!.isNotEmpty) 'wardCode': wardCode,
        if (postalCode != null && postalCode!.isNotEmpty)
          'postalCode': postalCode,
        'isDefault': isDefault,
      };
}

/// CRUD over the signed-in customer's address book.
abstract class AddressesRepository {
  Future<Result<List<Address>, AppFailure>> list();

  Future<Result<Address, AppFailure>> create(AddressDraft draft);

  Future<Result<Address, AppFailure>> update(String id, AddressDraft draft);

  Future<Result<Address, AppFailure>> setDefault(String id);

  Future<Result<void, AppFailure>> delete(String id);
}

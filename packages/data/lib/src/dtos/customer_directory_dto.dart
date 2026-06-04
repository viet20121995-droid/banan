import 'package:banan_domain/banan_domain.dart';

import 'address_dto.dart';

class CustomerSummaryDto {
  const CustomerSummaryDto(this._json);

  factory CustomerSummaryDto.fromJson(Map<String, dynamic> json) =>
      CustomerSummaryDto(json);
  final Map<String, dynamic> _json;

  CustomerSummary toDomain() => CustomerSummary(
        id: _json['id'] as String,
        fullName: _json['fullName'] as String,
        email: _json['email'] as String,
        phone: _json['phone'] as String?,
        avatarUrl: _json['avatarUrl'] as String?,
        membershipTier:
            MembershipTier.fromWire(_json['membershipTier'] as String),
        pointsBalance: (_json['pointsBalance'] as num).toInt(),
        orderCount: (_json['orderCount'] as num).toInt(),
        totalSpentVnd: (_json['totalSpentVnd'] as num).toInt(),
        tags: ((_json['merchantTags'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        lastOrderAt: _json['lastOrderAt'] == null
            ? null
            : DateTime.tryParse(_json['lastOrderAt'] as String),
      );
}

class CustomerDetailDto {
  const CustomerDetailDto(this._json);

  factory CustomerDetailDto.fromJson(Map<String, dynamic> json) =>
      CustomerDetailDto(json);
  final Map<String, dynamic> _json;

  CustomerDetail toDomain() {
    final addresses = (_json['addresses'] as List? ?? const [])
        .map((e) => AddressDto.fromJson(e as Map<String, dynamic>).toDomain())
        .toList();
    final orders = (_json['orders'] as List? ?? const [])
        .map((e) {
          final o = e as Map<String, dynamic>;
          return CustomerOrderLine(
            id: o['id'] as String,
            code: o['code'] as String,
            status: o['status'] as String,
            fulfillmentType: o['fulfillmentType'] as String,
            totalVnd: (o['totalVnd'] as num).toInt(),
            storeName: o['storeName'] as String? ?? '',
            createdAt: DateTime.parse(o['createdAt'] as String),
          );
        })
        .toList();
    return CustomerDetail(
      id: _json['id'] as String,
      fullName: _json['fullName'] as String,
      email: _json['email'] as String,
      phone: _json['phone'] as String?,
      avatarUrl: _json['avatarUrl'] as String?,
      birthday: _json['birthday'] == null
          ? null
          : DateTime.tryParse(_json['birthday'] as String),
      membershipTier:
          MembershipTier.fromWire(_json['membershipTier'] as String),
      pointsBalance: (_json['pointsBalance'] as num).toInt(),
      orderCount: (_json['orderCount'] as num).toInt(),
      totalSpentVnd: (_json['totalSpentVnd'] as num).toInt(),
      memberSince: DateTime.parse(_json['createdAt'] as String),
      addresses: addresses,
      orders: orders,
      notes: _json['merchantNotes'] as String?,
      tags: ((_json['merchantTags'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

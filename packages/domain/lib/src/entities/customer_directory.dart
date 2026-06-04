import 'package:equatable/equatable.dart';

import 'address.dart';
import 'role.dart';

/// Row in the merchant's customer directory.
class CustomerSummary extends Equatable {
  const CustomerSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.membershipTier,
    required this.pointsBalance,
    required this.orderCount,
    required this.totalSpentVnd,
    this.phone,
    this.avatarUrl,
    this.tags = const [],
    this.lastOrderAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final MembershipTier membershipTier;
  final int pointsBalance;
  final int orderCount;
  final int totalSpentVnd;
  final List<String> tags;
  final DateTime? lastOrderAt;

  @override
  List<Object?> get props => [
        id,
        fullName,
        email,
        phone,
        avatarUrl,
        membershipTier,
        pointsBalance,
        orderCount,
        totalSpentVnd,
        tags,
        lastOrderAt,
      ];
}

/// One past order shown on the customer card.
class CustomerOrderLine extends Equatable {
  const CustomerOrderLine({
    required this.id,
    required this.code,
    required this.status,
    required this.fulfillmentType,
    required this.totalVnd,
    required this.storeName,
    required this.createdAt,
  });

  final String id;
  final String code;
  final String status;
  final String fulfillmentType;
  final int totalVnd;
  final String storeName;
  final DateTime createdAt;

  @override
  List<Object?> get props =>
      [id, code, status, fulfillmentType, totalVnd, storeName, createdAt];
}

/// Full customer card: profile + address book + recent orders.
class CustomerDetail extends Equatable {
  const CustomerDetail({
    required this.id,
    required this.fullName,
    required this.email,
    required this.membershipTier,
    required this.pointsBalance,
    required this.orderCount,
    required this.totalSpentVnd,
    required this.memberSince,
    required this.addresses,
    required this.orders,
    this.phone,
    this.avatarUrl,
    this.birthday,
    this.notes,
    this.tags = const [],
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final DateTime? birthday;
  final MembershipTier membershipTier;
  final int pointsBalance;
  final int orderCount;
  final int totalSpentVnd;
  final DateTime memberSince;
  final List<Address> addresses;
  final List<CustomerOrderLine> orders;

  /// Private merchant CRM — not visible to the customer.
  final String? notes;
  final List<String> tags;

  @override
  List<Object?> get props => [
        id,
        fullName,
        email,
        phone,
        avatarUrl,
        birthday,
        membershipTier,
        pointsBalance,
        orderCount,
        totalSpentVnd,
        memberSince,
        addresses,
        orders,
        notes,
        tags,
      ];
}

/// One page of customer summaries.
class CustomerPage extends Equatable {
  const CustomerPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<CustomerSummary> items;
  final int page;
  final int perPage;
  final int total;

  @override
  List<Object?> get props => [items, page, perPage, total];
}

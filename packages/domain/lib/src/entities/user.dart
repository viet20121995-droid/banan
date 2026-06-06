import 'package:equatable/equatable.dart';

import 'role.dart';

/// Customer's self-declared gender. Mirrors the backend `Gender` enum
/// (`MALE` / `FEMALE` / `OTHER`). Nullable on the user — may be unset.
enum Gender {
  male,
  female,
  other;

  static Gender fromWire(String value) {
    switch (value) {
      case 'MALE':
        return Gender.male;
      case 'FEMALE':
        return Gender.female;
      case 'OTHER':
        return Gender.other;
      default:
        throw FormatException('Unknown gender: $value');
    }
  }

  String get wire {
    switch (this) {
      case Gender.male:
        return 'MALE';
      case Gender.female:
        return 'FEMALE';
      case Gender.other:
        return 'OTHER';
    }
  }

  /// Vietnamese label for selectors / display.
  String get label {
    switch (this) {
      case Gender.male:
        return 'Nam';
      case Gender.female:
        return 'Nữ';
      case Gender.other:
        return 'Khác';
    }
  }
}

class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.membershipTier,
    required this.pointsBalance,
    this.phone,
    this.avatarUrl,
    this.birthday,
    this.gender,
    this.storeId,
    this.kitchenId,
    this.marketingOptIn = true,
    this.orderUpdatesOptIn = true,
  });

  final String id;
  final String email;
  final String? phone;
  final String fullName;
  final String? avatarUrl;
  final Role role;
  final MembershipTier membershipTier;
  final int pointsBalance;
  final DateTime? birthday;

  /// Customer's self-declared gender (nullable — may be unset).
  final Gender? gender;
  final String? storeId;
  final String? kitchenId;

  /// Whether the customer opted in to promotional / marketing messages.
  final bool marketingOptIn;

  /// Whether the customer opted in to order-status update notifications.
  final bool orderUpdatesOptIn;

  @override
  List<Object?> get props => [
        id,
        email,
        phone,
        fullName,
        avatarUrl,
        role,
        membershipTier,
        pointsBalance,
        birthday,
        gender,
        storeId,
        kitchenId,
        marketingOptIn,
        orderUpdatesOptIn,
      ];
}

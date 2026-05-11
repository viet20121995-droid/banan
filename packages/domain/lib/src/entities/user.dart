import 'package:equatable/equatable.dart';

import 'role.dart';

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
    this.storeId,
    this.kitchenId,
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
  final String? storeId;
  final String? kitchenId;

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
        storeId,
        kitchenId,
      ];
}

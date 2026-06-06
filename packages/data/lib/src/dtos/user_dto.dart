import 'package:banan_domain/banan_domain.dart';

/// Wire format for User. Server uses ALL_CAPS for enums.
class UserDto {
  const UserDto({
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

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      fullName: json['fullName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String,
      membershipTier: json['membershipTier'] as String,
      pointsBalance: (json['pointsBalance'] as num).toInt(),
      birthday: json['birthday'] as String?,
      gender: json['gender'] as String?,
      storeId: json['storeId'] as String?,
      kitchenId: json['kitchenId'] as String?,
      marketingOptIn: json['marketingOptIn'] as bool? ?? true,
      orderUpdatesOptIn: json['orderUpdatesOptIn'] as bool? ?? true,
    );
  }

  final String id;
  final String email;
  final String? phone;
  final String fullName;
  final String? avatarUrl;
  final String role;
  final String membershipTier;
  final int pointsBalance;
  final String? birthday;
  final String? gender;
  final String? storeId;
  final String? kitchenId;
  final bool marketingOptIn;
  final bool orderUpdatesOptIn;

  User toDomain() {
    return User(
      id: id,
      email: email,
      phone: phone,
      fullName: fullName,
      avatarUrl: avatarUrl,
      role: Role.fromWire(role),
      membershipTier: MembershipTier.fromWire(membershipTier),
      pointsBalance: pointsBalance,
      birthday: birthday == null ? null : DateTime.tryParse(birthday!),
      gender: gender == null ? null : Gender.fromWire(gender!),
      storeId: storeId,
      kitchenId: kitchenId,
      marketingOptIn: marketingOptIn,
      orderUpdatesOptIn: orderUpdatesOptIn,
    );
  }
}

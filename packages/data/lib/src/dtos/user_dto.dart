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
    this.storeId,
    this.kitchenId,
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
      storeId: json['storeId'] as String?,
      kitchenId: json['kitchenId'] as String?,
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
  final String? storeId;
  final String? kitchenId;

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
      storeId: storeId,
      kitchenId: kitchenId,
    );
  }
}

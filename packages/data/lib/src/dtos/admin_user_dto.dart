import 'package:banan_domain/banan_domain.dart';

class AdminUserDto {
  const AdminUserDto(this._json);

  factory AdminUserDto.fromJson(Map<String, dynamic> json) =>
      AdminUserDto(json);
  final Map<String, dynamic> _json;

  AdminUser toDomain() => AdminUser(
        id: _json['id'] as String,
        email: _json['email'] as String,
        fullName: _json['fullName'] as String,
        phone: _json['phone'] as String?,
        role: Role.fromWire(_json['role'] as String),
        storeName: _json['storeName'] as String?,
        kitchenName: _json['kitchenName'] as String?,
        createdAt: DateTime.parse(_json['createdAt'] as String),
      );
}

class OrgOptionDto {
  const OrgOptionDto(this._json);

  factory OrgOptionDto.fromJson(Map<String, dynamic> json) =>
      OrgOptionDto(json);
  final Map<String, dynamic> _json;

  OrgOption toDomain() =>
      OrgOption(id: _json['id'] as String, name: _json['name'] as String);
}

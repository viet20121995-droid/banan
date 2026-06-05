import 'package:equatable/equatable.dart';

import 'role.dart';

/// A user row in the admin accounts console.
class AdminUser extends Equatable {
  const AdminUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
    this.isActive = true,
    this.phone,
    this.storeId,
    this.storeName,
    this.kitchenId,
    this.kitchenName,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final Role role;
  final bool isActive;
  final String? storeId;
  final String? storeName;
  final String? kitchenId;
  final String? kitchenName;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        email,
        fullName,
        phone,
        role,
        isActive,
        storeId,
        storeName,
        kitchenId,
        kitchenName,
        createdAt,
      ];
}

/// A selectable store / kitchen when provisioning a staff account.
class OrgOption extends Equatable {
  const OrgOption({required this.id, required this.name});
  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// One page of admin users.
class AdminUserPage extends Equatable {
  const AdminUserPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<AdminUser> items;
  final int page;
  final int perPage;
  final int total;

  @override
  List<Object?> get props => [items, page, perPage, total];
}

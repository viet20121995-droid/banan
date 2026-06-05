import 'package:banan_core/banan_core.dart';

import '../entities/admin_user.dart';
import '../entities/role.dart';

/// Payload for provisioning a sub-account.
class NewUserDraft {
  const NewUserDraft({
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
    this.phone,
    this.storeId,
    this.kitchenId,
  });

  final String email;
  final String password;
  final String fullName;
  final String? phone;
  final Role role;
  final String? storeId;
  final String? kitchenId;

  String get _roleWire => switch (role) {
        Role.customer => 'CUSTOMER',
        Role.merchantOwner => 'MERCHANT_OWNER',
        Role.merchantStaff => 'MERCHANT_STAFF',
        Role.kitchenManager => 'KITCHEN_MANAGER',
        Role.kitchenStaff => 'KITCHEN_STAFF',
        Role.admin => 'ADMIN',
      };

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'fullName': fullName,
        'role': _roleWire,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (storeId != null) 'storeId': storeId,
        if (kitchenId != null) 'kitchenId': kitchenId,
      };
}

/// Payload for editing an existing account. Only non-null fields are sent.
class EditUserDraft {
  const EditUserDraft({
    this.email,
    this.fullName,
    this.phone,
    this.role,
    this.storeId,
    this.kitchenId,
    this.isActive,
  });

  final String? email;
  final String? fullName;
  final String? phone;
  final Role? role;
  final String? storeId;
  final String? kitchenId;
  final bool? isActive;

  static String _wire(Role r) => switch (r) {
        Role.customer => 'CUSTOMER',
        Role.merchantOwner => 'MERCHANT_OWNER',
        Role.merchantStaff => 'MERCHANT_STAFF',
        Role.kitchenManager => 'KITCHEN_MANAGER',
        Role.kitchenStaff => 'KITCHEN_STAFF',
        Role.admin => 'ADMIN',
      };

  Map<String, dynamic> toJson() => {
        if (email != null) 'email': email,
        if (fullName != null) 'fullName': fullName,
        if (phone != null) 'phone': phone,
        if (role != null) 'role': _wire(role!),
        if (storeId != null) 'storeId': storeId,
        if (kitchenId != null) 'kitchenId': kitchenId,
        if (isActive != null) 'isActive': isActive,
      };
}

/// Admin-only console: provision, list, edit, and disable sub-accounts.
abstract class AdminRepository {
  Future<Result<AdminUserPage, AppFailure>> listUsers({
    String? role,
    String? q,
    int page = 1,
    int perPage = 30,
  });

  Future<Result<AdminUser, AppFailure>> createUser(NewUserDraft draft);

  /// Edit an existing account (name/email/phone/role/linkage/active).
  Future<Result<AdminUser, AppFailure>> updateUser(
    String id,
    EditUserDraft draft,
  );

  /// Set a new password for a user (admin-initiated; revokes their sessions).
  Future<Result<bool, AppFailure>> resetUserPassword(String id, String password);

  /// Disable an account (soft-delete: blocks login, keeps history).
  Future<Result<bool, AppFailure>> deactivateUser(String id);

  Future<Result<List<OrgOption>, AppFailure>> stores();

  Future<Result<List<OrgOption>, AppFailure>> kitchens();
}

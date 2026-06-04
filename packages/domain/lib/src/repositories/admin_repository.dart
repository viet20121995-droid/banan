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

/// Admin-only console: provision and list sub-accounts.
abstract class AdminRepository {
  Future<Result<AdminUserPage, AppFailure>> listUsers({
    String? role,
    String? q,
    int page = 1,
    int perPage = 30,
  });

  Future<Result<AdminUser, AppFailure>> createUser(NewUserDraft draft);

  Future<Result<List<OrgOption>, AppFailure>> stores();

  Future<Result<List<OrgOption>, AppFailure>> kitchens();
}

import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/admin_api.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._api);
  final AdminApi _api;

  @override
  Future<Result<AdminUserPage, AppFailure>> listUsers({
    String? role,
    String? q,
    int page = 1,
    int perPage = 30,
  }) =>
      _api.listUsers(role: role, q: q, page: page, perPage: perPage);

  @override
  Future<Result<AdminUser, AppFailure>> createUser(NewUserDraft draft) =>
      _api.createUser(draft.toJson());

  @override
  Future<Result<AdminUser, AppFailure>> updateUser(
    String id,
    EditUserDraft draft,
  ) =>
      _api.updateUser(id, draft.toJson());

  @override
  Future<Result<bool, AppFailure>> resetUserPassword(
    String id,
    String password,
  ) =>
      _api.resetUserPassword(id, password);

  @override
  Future<Result<bool, AppFailure>> deactivateUser(String id) =>
      _api.deactivateUser(id);

  @override
  Future<Result<List<OrgOption>, AppFailure>> stores() => _api.stores();

  @override
  Future<Result<List<OrgOption>, AppFailure>> kitchens() => _api.kitchens();
}

import 'dart:typed_data';

import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/customers_api.dart';

class CustomersRepositoryImpl implements CustomersRepository {
  CustomersRepositoryImpl(this._api);
  final CustomersApi _api;

  @override
  Future<Result<CustomerPage, AppFailure>> list({
    String? q,
    int page = 1,
    int perPage = 30,
  }) =>
      _api.list(q: q, page: page, perPage: perPage);

  @override
  Future<Result<CustomerDetail, AppFailure>> detail(String id) =>
      _api.detail(id);

  @override
  Future<Result<void, AppFailure>> updateProfile({
    required String customerId,
    String? fullName,
    String? phone,
    String? email,
    String? birthday,
  }) async {
    final res = await _api.updateProfile(
      customerId,
      fullName: fullName,
      phone: phone,
      email: email,
      birthday: birthday,
    );
    return res.map((_) {});
  }

  @override
  Future<Result<Uint8List, AppFailure>> exportCsv({String? q}) =>
      _api.exportCsv(q: q);

  @override
  Future<Result<void, AppFailure>> notify({
    required String customerId,
    required String title,
    required String body,
  }) =>
      _api.notify(customerId, {'title': title, 'body': body});

  @override
  Future<Result<int, AppFailure>> adjustPoints({
    required String customerId,
    required int delta,
    required String reason,
  }) async {
    final res = await _api.post(
      '/merchant/customers/$customerId/points',
      {'delta': delta, 'reason': reason},
    );
    return res.map((d) => (d['balance'] as num).toInt());
  }

  @override
  Future<Result<({String? notes, List<String> tags}), AppFailure>>
      updateNotes({
    required String customerId,
    String? notes,
    List<String>? tags,
  }) async {
    final res = await _api.patch(
      '/merchant/customers/$customerId/notes',
      {
        if (notes != null) 'notes': notes,
        if (tags != null) 'tags': tags,
      },
    );
    return res.map(
      (d) => (
        notes: d['merchantNotes'] as String?,
        tags: ((d['merchantTags'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      ),
    );
  }

  @override
  Future<Result<int, AppFailure>> broadcast({
    required String title,
    required String body,
    String? tag,
  }) async {
    final res = await _api.post(
      '/merchant/customers/broadcast',
      {
        'title': title,
        'body': body,
        if (tag != null && tag.isNotEmpty) 'tag': tag,
      },
    );
    return res.map((d) => (d['sent'] as num).toInt());
  }

  @override
  Future<Result<String, AppFailure>> issueCoupon({
    required String customerId,
    required GiftCouponType type,
    required int value,
    required int days, int? minSubtotalVnd,
  }) async {
    final res = await _api.post(
      '/merchant/customers/$customerId/coupon',
      {
        'type': type.wire,
        'value': value,
        if (minSubtotalVnd != null && minSubtotalVnd > 0)
          'minSubtotalVnd': minSubtotalVnd,
        'days': days,
      },
    );
    return res.map((d) => d['code'] as String);
  }
}

import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/refunds_api.dart';

class RefundRepositoryImpl implements RefundRepository {
  RefundRepositoryImpl(this._api);
  final RefundsApi _api;

  @override
  Future<Result<RefundPage, AppFailure>> list({
    RefundStatus? status,
    int page = 1,
    int perPage = 30,
  }) async {
    final wire = switch (status) {
      RefundStatus.requested => 'REQUESTED',
      RefundStatus.approved => 'APPROVED',
      RefundStatus.processing => 'PROCESSING',
      RefundStatus.completed => 'COMPLETED',
      RefundStatus.rejected => 'REJECTED',
      // No server-side filter value — a list build that doesn't recognise this
      // status simply lists everything rather than sending a bogus filter.
      RefundStatus.unknown => null,
      null => null,
    };
    final res = await _api.list(status: wire, page: page, perPage: perPage);
    return res.map(
      (data) => RefundPage(
        items: data.items.map((d) => d.toDomain()).toList(),
        page: data.page,
        perPage: data.perPage,
        total: data.total,
      ),
    );
  }

  @override
  Future<Result<Refund, AppFailure>> approve(String id) async {
    final res = await _api.approve(id);
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Refund, AppFailure>> reject(String id, {String? reason}) async {
    final res = await _api.reject(id, reason: reason);
    return res.map((d) => d.toDomain());
  }
}

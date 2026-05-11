import 'package:banan_core/banan_core.dart';
import 'package:equatable/equatable.dart';

import '../entities/refund.dart';

class RefundPage extends Equatable {
  const RefundPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<Refund> items;
  final int page;
  final int perPage;
  final int total;

  @override
  List<Object?> get props => [items, page, perPage, total];
}

abstract class RefundRepository {
  /// Merchant inbox — defaults to all statuses, optionally filtered.
  Future<Result<RefundPage, AppFailure>> list({
    RefundStatus? status,
    int page = 1,
    int perPage = 30,
  });

  Future<Result<Refund, AppFailure>> approve(String id);
  Future<Result<Refund, AppFailure>> reject(String id, {String? reason});
}

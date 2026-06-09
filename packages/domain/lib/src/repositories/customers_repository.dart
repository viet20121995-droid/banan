import 'dart:typed_data';

import 'package:banan_core/banan_core.dart';

import '../entities/customer_directory.dart';

/// Coupon kinds a merchant can gift to a customer.
enum GiftCouponType { percent, fixed, freeDelivery }

extension GiftCouponTypeWire on GiftCouponType {
  String get wire => switch (this) {
        GiftCouponType.percent => 'PERCENT',
        GiftCouponType.fixed => 'FIXED',
        GiftCouponType.freeDelivery => 'FREE_DELIVERY',
      };
}

/// Merchant-facing read model + interactions over served customers.
abstract class CustomersRepository {
  Future<Result<CustomerPage, AppFailure>> list({
    String? q,
    int page = 1,
    int perPage = 30,
  });

  Future<Result<CustomerDetail, AppFailure>> detail(String id);

  /// Edit a customer's core profile (name / phone / email / birthday).
  /// Only non-null fields change; pass an empty [birthday] to clear it.
  Future<Result<void, AppFailure>> updateProfile({
    required String customerId,
    String? fullName,
    String? phone,
    String? email,
    String? birthday,
  });

  /// Download the (optionally searched) customer directory as CSV bytes.
  Future<Result<Uint8List, AppFailure>> exportCsv({String? q});

  /// Send a free-text in-app + email message to the customer.
  Future<Result<void, AppFailure>> notify({
    required String customerId,
    required String title,
    required String body,
  });

  /// Gift or deduct Micho points. Returns the new balance.
  Future<Result<int, AppFailure>> adjustPoints({
    required String customerId,
    required int delta,
    required String reason,
  });

  /// Update private staff notes / tags. Returns the saved notes + tags.
  Future<Result<({String? notes, List<String> tags}), AppFailure>>
      updateNotes({
    required String customerId,
    String? notes,
    List<String>? tags,
  });

  /// Broadcast an announcement to all served customers (optionally a
  /// segment by staff tag). Returns the count sent.
  Future<Result<int, AppFailure>> broadcast({
    required String title,
    required String body,
    String? tag,
  });

  /// Issue a single-use personal coupon and notify the customer.
  /// Returns the generated code.
  Future<Result<String, AppFailure>> issueCoupon({
    required String customerId,
    required GiftCouponType type,
    required int value,
    required int days, int? minSubtotalVnd,
  });
}

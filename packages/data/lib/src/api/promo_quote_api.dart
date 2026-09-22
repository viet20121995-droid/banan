import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

/// A product the customer may add to receive it free (gift with purchase).
class PromoGiftProduct {
  const PromoGiftProduct({required this.id, required this.name});
  final String id;
  final String name;
}

/// A campaign the cart is close to (or already qualifies for) but that has
/// nothing to discount yet — the checkout nudges the customer with it.
class PromoHint {
  const PromoHint({
    required this.campaignId,
    required this.name,
    required this.type,
    required this.shortVnd,
    required this.minSubtotalVnd,
    this.giftProducts = const [],
  });

  factory PromoHint.fromJson(Map<String, dynamic> j) => PromoHint(
        campaignId: j['campaignId'] as String,
        name: j['name'] as String? ?? '',
        type: j['type'] as String? ?? '',
        shortVnd: (j['shortVnd'] as num?)?.toDouble() ?? 0,
        minSubtotalVnd: (j['minSubtotalVnd'] as num?)?.toDouble() ?? 0,
        giftProducts: ((j['giftProducts'] as List?) ?? const [])
            .map(
              (e) => PromoGiftProduct(
                id: (e as Map)['id'] as String,
                name: e['name'] as String? ?? '',
              ),
            )
            .toList(),
      );

  final String campaignId;
  final String name;

  /// Wire campaign type, e.g. `GIFT_WITH_PURCHASE`, `FIRST_ORDER`.
  final String type;

  /// ₫ still missing to reach the campaign's minimum (0 = reached).
  final double shortVnd;
  final double minSubtotalVnd;
  final List<PromoGiftProduct> giftProducts;

  bool get isGift => type == 'GIFT_WITH_PURCHASE';
}

class PromoApplied {
  const PromoApplied({
    required this.id,
    required this.name,
    required this.discountVnd,
  });
  final String id;
  final String name;
  final double discountVnd;
}

/// Result of `POST /promotions/quote` — what the automatic campaign engine
/// will take off this cart, plus nudges for campaigns within reach.
class PromoQuote {
  const PromoQuote({
    required this.discountVnd,
    required this.applied,
    required this.hints,
  });

  factory PromoQuote.fromJson(Map<String, dynamic> j) => PromoQuote(
        discountVnd: (j['discountVnd'] as num?)?.toDouble() ?? 0,
        applied: ((j['applied'] as List?) ?? const [])
            .map(
              (e) => PromoApplied(
                id: (e as Map)['id'] as String,
                name: e['name'] as String? ?? '',
                discountVnd: (e['discountVnd'] as num?)?.toDouble() ?? 0,
              ),
            )
            .toList(),
        hints: ((j['hints'] as List?) ?? const [])
            .map((e) => PromoHint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static const empty = PromoQuote(discountVnd: 0, applied: [], hints: []);

  final double discountVnd;
  final List<PromoApplied> applied;
  final List<PromoHint> hints;
}

class PromoQuoteLine {
  const PromoQuoteLine({
    required this.productId,
    required this.quantity,
    required this.lineTotalVnd,
    this.comboLine = false,
  });
  final String productId;
  final int quantity;
  final double lineTotalVnd;
  final bool comboLine;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'lineTotalVnd': lineTotalVnd,
        if (comboLine) 'comboLine': true,
      };
}

class PromoQuoteApi {
  PromoQuoteApi(this._dio);
  final Dio _dio;

  Future<Result<PromoQuote, AppFailure>> quote({
    required List<PromoQuoteLine> lines,
    required double subtotalVnd,
    String? storeId,
    String? guestPhone,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/promotions/quote',
        data: {
          'lines': lines.map((l) => l.toJson()).toList(),
          'subtotalVnd': subtotalVnd,
          if (storeId != null) 'storeId': storeId,
          if (guestPhone != null && guestPhone.isNotEmpty)
            'guestPhone': guestPhone,
        },
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(PromoQuote.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}

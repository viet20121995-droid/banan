import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

/// One marketing program: an on/off flag plus its free-form config map.
class MarketingProgram {
  const MarketingProgram({required this.enabled, required this.config});
  factory MarketingProgram.fromJson(Map<String, dynamic>? j) =>
      MarketingProgram(
        enabled: (j?['enabled'] as bool?) ?? false,
        config: (j?['config'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
  final bool enabled;
  final Map<String, dynamic> config;

  num numCfg(String key, [num fallback = 0]) =>
      (config[key] as num?) ?? fallback;
  String strCfg(String key, [String fallback = '']) =>
      (config[key] as String?) ?? fallback;
  List<dynamic> listCfg(String key) => (config[key] as List?) ?? const [];
}

class MarketingConfig {
  const MarketingConfig({
    required this.referral,
    required this.giftCard,
    required this.subscription,
    required this.catering,
    required this.rewards,
  });

  factory MarketingConfig.fromJson(Map<String, dynamic> j) => MarketingConfig(
        referral:
            MarketingProgram.fromJson(j['referral'] as Map<String, dynamic>?),
        giftCard:
            MarketingProgram.fromJson(j['giftCard'] as Map<String, dynamic>?),
        subscription: MarketingProgram.fromJson(
            j['subscription'] as Map<String, dynamic>?),
        catering:
            MarketingProgram.fromJson(j['catering'] as Map<String, dynamic>?),
        rewards:
            MarketingProgram.fromJson(j['rewards'] as Map<String, dynamic>?),
      );

  static const empty = MarketingConfig(
    referral: MarketingProgram(enabled: false, config: {}),
    giftCard: MarketingProgram(enabled: false, config: {}),
    subscription: MarketingProgram(enabled: false, config: {}),
    catering: MarketingProgram(enabled: false, config: {}),
    rewards: MarketingProgram(enabled: false, config: {}),
  );

  final MarketingProgram referral;
  final MarketingProgram giftCard;
  final MarketingProgram subscription;
  final MarketingProgram catering;
  final MarketingProgram rewards;

  /// True when at least one program is live (drives the footer "Ưu đãi" group).
  bool get anyEnabled =>
      referral.enabled ||
      giftCard.enabled ||
      subscription.enabled ||
      catering.enabled ||
      rewards.enabled;
}

/// Admin-controlled marketing programs. Public read (gating) + admin write.
class MarketingApi {
  MarketingApi(this._dio);
  final Dio _dio;

  Future<Result<MarketingConfig, AppFailure>> get() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/marketing/config');
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(MarketingConfig.fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Admin patch — send only the changed flags/configs.
  Future<Result<MarketingConfig, AppFailure>> update(
    Map<String, dynamic> patch,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/merchant/marketing/config',
        data: patch,
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(MarketingConfig.fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}

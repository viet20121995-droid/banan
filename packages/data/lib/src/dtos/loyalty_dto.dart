import 'package:banan_domain/banan_domain.dart';

class LoyaltyEventDto {
  const LoyaltyEventDto({
    required this.id,
    required this.userId,
    required this.type,
    required this.delta,
    required this.balanceAfter,
    required this.createdAt,
    this.orderId,
    this.reason,
  });

  factory LoyaltyEventDto.fromJson(Map<String, dynamic> json) {
    return LoyaltyEventDto(
      id: json['id'] as String,
      userId: json['userId'] as String,
      orderId: json['orderId'] as String?,
      type: json['type'] as String,
      delta: (json['delta'] as num).toInt(),
      balanceAfter: (json['balanceAfter'] as num).toInt(),
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String userId;
  final String? orderId;
  final String type;
  final int delta;
  final int balanceAfter;
  final String? reason;
  final DateTime createdAt;

  LoyaltyEvent toDomain() => LoyaltyEvent(
        id: id,
        userId: userId,
        orderId: orderId,
        type: LoyaltyEventType.fromWire(type),
        delta: delta,
        balanceAfter: balanceAfter,
        reason: reason,
        createdAt: createdAt,
      );
}

class MembershipSummaryDto {
  const MembershipSummaryDto({
    required this.tier,
    required this.balance,
    required this.history,
    required this.earnRatePerVnd,
    required this.redemptionValueVnd,
    required this.tierThresholds,
    this.birthday,
  });

  factory MembershipSummaryDto.fromJson(Map<String, dynamic> json) {
    final thresholds =
        (json['thresholds'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MembershipSummaryDto(
      tier: json['tier'] as String,
      balance: (json['balance'] as num).toInt(),
      birthday: json['birthday'] as String?,
      history: ((json['history'] as List?) ?? const [])
          .map((e) => LoyaltyEventDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      earnRatePerVnd: (json['earnRatePerVnd'] as num?)?.toInt() ?? 10000,
      redemptionValueVnd:
          (json['redemptionValueVnd'] as num?)?.toInt() ?? 100,
      tierThresholds: {
        for (final entry in thresholds.entries)
          entry.key: (entry.value as num).toInt(),
      },
    );
  }

  final String tier;
  final int balance;
  final String? birthday;
  final List<LoyaltyEventDto> history;
  final int earnRatePerVnd;
  final int redemptionValueVnd;
  final Map<String, int> tierThresholds;

  MembershipSummary toDomain() => MembershipSummary(
        tier: MembershipTier.fromWire(tier.toUpperCase()),
        balance: balance,
        birthday: birthday == null ? null : DateTime.tryParse(birthday!),
        history: history.map((h) => h.toDomain()).toList(),
        earnRatePerVnd: earnRatePerVnd,
        redemptionValueVnd: redemptionValueVnd,
        tierThresholds: {
          MembershipTier.silver: tierThresholds['silver'] ?? 0,
          MembershipTier.gold: tierThresholds['gold'] ?? 1000,
          MembershipTier.platinum: tierThresholds['platinum'] ?? 5000,
        },
      );
}

import 'package:equatable/equatable.dart';

import 'role.dart';

enum LoyaltyEventType {
  earn,
  redeem,
  expire,
  birthday,
  adjustment;

  static LoyaltyEventType fromWire(String value) {
    switch (value) {
      case 'EARN':
        return LoyaltyEventType.earn;
      case 'REDEEM':
        return LoyaltyEventType.redeem;
      case 'EXPIRE':
        return LoyaltyEventType.expire;
      case 'BIRTHDAY':
        return LoyaltyEventType.birthday;
      case 'ADJUSTMENT':
        return LoyaltyEventType.adjustment;
      default:
        throw FormatException('Unknown loyalty event type: $value');
    }
  }

  String get label {
    switch (this) {
      case LoyaltyEventType.earn:
        return 'Earned';
      case LoyaltyEventType.redeem:
        return 'Redeemed';
      case LoyaltyEventType.expire:
        return 'Expired';
      case LoyaltyEventType.birthday:
        return 'Birthday gift';
      case LoyaltyEventType.adjustment:
        return 'Adjustment';
    }
  }
}

class LoyaltyEvent extends Equatable {
  const LoyaltyEvent({
    required this.id,
    required this.userId,
    required this.type,
    required this.delta,
    required this.balanceAfter,
    required this.createdAt,
    this.orderId,
    this.reason,
  });

  final String id;
  final String userId;
  final String? orderId;
  final LoyaltyEventType type;
  final int delta;
  final int balanceAfter;
  final String? reason;
  final DateTime createdAt;

  @override
  List<Object?> get props =>
      [id, userId, orderId, type, delta, balanceAfter, reason, createdAt];
}

class MembershipSummary extends Equatable {
  const MembershipSummary({
    required this.tier,
    required this.balance,
    required this.history,
    required this.earnRatePerVnd,
    required this.redemptionValueVnd,
    required this.tierThresholds,
    this.birthday,
  });

  final MembershipTier tier;
  final int balance;
  final DateTime? birthday;
  final List<LoyaltyEvent> history;
  final int earnRatePerVnd;
  final int redemptionValueVnd;
  final Map<MembershipTier, int> tierThresholds;

  /// Points needed to reach the next tier (null if at top tier).
  int? get pointsToNextTier {
    final next = nextTier;
    if (next == null) return null;
    final nextThreshold = tierThresholds[next] ?? 0;
    final delta = nextThreshold - balance;
    return delta > 0 ? delta : null;
  }

  /// The tier directly above the current one, or null if already at the top.
  MembershipTier? get nextTier {
    const ladder = [
      MembershipTier.bronze,
      MembershipTier.silver,
      MembershipTier.gold,
      MembershipTier.platinum,
    ];
    final idx = ladder.indexOf(tier);
    if (idx < 0 || idx == ladder.length - 1) return null;
    return ladder[idx + 1];
  }

  @override
  List<Object?> get props => [
        tier,
        balance,
        birthday,
        history,
        earnRatePerVnd,
        redemptionValueVnd,
        tierThresholds,
      ];
}

import 'package:equatable/equatable.dart';

/// Promotion campaign types. Phase 1 builds editors for the first four;
/// the remaining types are recognised by the data layer (so existing
/// campaigns round-trip) but surfaced as "coming soon" in the UI.
enum CampaignType {
  productDiscount,
  categoryDiscount,
  flashSale,
  happyHour,
  buyXGetY,
  firstOrder,
  birthday,
  reactivation,
  membershipBenefit;

  /// Wire (API) string ↔ enum. Throws on an unknown value so a backend
  /// addition surfaces loudly instead of silently dropping campaigns.
  static CampaignType fromWire(String value) {
    switch (value) {
      case 'PRODUCT_DISCOUNT':
        return CampaignType.productDiscount;
      case 'CATEGORY_DISCOUNT':
        return CampaignType.categoryDiscount;
      case 'FLASH_SALE':
        return CampaignType.flashSale;
      case 'HAPPY_HOUR':
        return CampaignType.happyHour;
      case 'BUY_X_GET_Y':
        return CampaignType.buyXGetY;
      case 'FIRST_ORDER':
        return CampaignType.firstOrder;
      case 'BIRTHDAY':
        return CampaignType.birthday;
      case 'REACTIVATION':
        return CampaignType.reactivation;
      case 'MEMBERSHIP_BENEFIT':
        return CampaignType.membershipBenefit;
      default:
        throw FormatException('Unknown campaign type: $value');
    }
  }

  String toWire() {
    switch (this) {
      case CampaignType.productDiscount:
        return 'PRODUCT_DISCOUNT';
      case CampaignType.categoryDiscount:
        return 'CATEGORY_DISCOUNT';
      case CampaignType.flashSale:
        return 'FLASH_SALE';
      case CampaignType.happyHour:
        return 'HAPPY_HOUR';
      case CampaignType.buyXGetY:
        return 'BUY_X_GET_Y';
      case CampaignType.firstOrder:
        return 'FIRST_ORDER';
      case CampaignType.birthday:
        return 'BIRTHDAY';
      case CampaignType.reactivation:
        return 'REACTIVATION';
      case CampaignType.membershipBenefit:
        return 'MEMBERSHIP_BENEFIT';
    }
  }

  /// Types that ship with a full create/edit editor. Phase 1 covered the
  /// first four; Phase 2 added Buy X Get Y, First Order, Birthday and
  /// Reactivation; Phase 3 adds Membership Benefit. All nine types are now
  /// editable in the merchant UI.
  bool get hasEditor =>
      this == CampaignType.productDiscount ||
      this == CampaignType.categoryDiscount ||
      this == CampaignType.flashSale ||
      this == CampaignType.happyHour ||
      this == CampaignType.buyXGetY ||
      this == CampaignType.firstOrder ||
      this == CampaignType.birthday ||
      this == CampaignType.reactivation ||
      this == CampaignType.membershipBenefit;
}

/// A promotion campaign as managed in the admin promotions screen.
///
/// [config] is a free-form JSON map whose shape depends on [type] — see the
/// backend contract. The data layer keeps it as `Map<String, dynamic>` so the
/// domain stays decoupled from the per-type schemas.
class Campaign extends Equatable {
  const Campaign({
    required this.id,
    required this.type,
    required this.name,
    required this.isActive,
    required this.priority,
    required this.stackable,
    required this.config,
    required this.usedCount,
    required this.createdAt,
    required this.updatedAt,
    this.startsAt,
    this.endsAt,
    this.storeId,
    this.usageLimit,
    this.perUserLimit,
  });

  final String id;
  final CampaignType type;
  final String name;
  final bool isActive;
  final int priority;
  final bool stackable;

  /// Optional live window. Null = no bound on that side.
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Type-specific settings (kind/value/scope/schedule). See backend contract.
  final Map<String, dynamic> config;

  /// Null = chain-wide (every store). A non-null id scopes it to one store.
  final String? storeId;

  /// Total redemptions allowed across everyone. Null = unlimited.
  final int? usageLimit;
  final int usedCount;

  /// Per-customer cap. Null = unlimited.
  final int? perUserLimit;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get chainWide => storeId == null;

  @override
  List<Object?> get props => [
        id,
        type,
        name,
        isActive,
        priority,
        stackable,
        startsAt,
        endsAt,
        config,
        storeId,
        usageLimit,
        usedCount,
        perUserLimit,
        createdAt,
        updatedAt,
      ];
}

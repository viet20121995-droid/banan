/// User role. Mirrors the backend Prisma `Role` enum exactly.
enum Role {
  customer,
  merchantOwner,
  merchantStaff,
  kitchenManager,
  kitchenStaff,
  admin;

  /// Parse from the wire format the backend sends (`MERCHANT_OWNER`, etc.).
  static Role fromWire(String value) {
    switch (value) {
      case 'CUSTOMER':
        return Role.customer;
      case 'MERCHANT_OWNER':
        return Role.merchantOwner;
      case 'MERCHANT_STAFF':
        return Role.merchantStaff;
      case 'KITCHEN_MANAGER':
        return Role.kitchenManager;
      case 'KITCHEN_STAFF':
        return Role.kitchenStaff;
      case 'ADMIN':
        return Role.admin;
      default:
        throw FormatException('Unknown role: $value');
    }
  }

  bool get isMerchant =>
      this == Role.merchantOwner || this == Role.merchantStaff;
  bool get isKitchen =>
      this == Role.kitchenManager || this == Role.kitchenStaff;
  bool get isCustomer => this == Role.customer;
  bool get isAdmin => this == Role.admin;
}

/// Loyalty membership tiers, lowest → highest. `bronze` is the base tier
/// every customer starts on. Mirrors the backend `MembershipTier` enum.
enum MembershipTier {
  bronze,
  silver,
  gold,
  platinum;

  static MembershipTier fromWire(String value) {
    switch (value) {
      case 'BRONZE':
        return MembershipTier.bronze;
      case 'SILVER':
        return MembershipTier.silver;
      case 'GOLD':
        return MembershipTier.gold;
      case 'PLATINUM':
        return MembershipTier.platinum;
      default:
        throw FormatException('Unknown tier: $value');
    }
  }

  String get wire {
    switch (this) {
      case MembershipTier.bronze:
        return 'BRONZE';
      case MembershipTier.silver:
        return 'SILVER';
      case MembershipTier.gold:
        return 'GOLD';
      case MembershipTier.platinum:
        return 'PLATINUM';
    }
  }

  /// Vietnamese display label.
  String get label {
    switch (this) {
      case MembershipTier.bronze:
        return 'Đồng';
      case MembershipTier.silver:
        return 'Bạc';
      case MembershipTier.gold:
        return 'Vàng';
      case MembershipTier.platinum:
        return 'Bạch kim';
    }
  }

  /// Rank from lowest (0 = Bronze) to highest (3 = Platinum).
  int get order => index;
}

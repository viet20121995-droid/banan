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

enum MembershipTier {
  silver,
  gold,
  platinum;

  static MembershipTier fromWire(String value) {
    switch (value) {
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
}

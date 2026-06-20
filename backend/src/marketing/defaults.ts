/**
 * Default config for each marketing program. Served (merged over any stored
 * values) so the admin editor and customer surfaces always have a sane
 * shape to render — even before the admin has saved anything. Every program
 * ships DISABLED; the admin flips it on from the merchant control center.
 */

export interface ReferralConfig {
  referrerPoints: number;
  refereePoints: number;
  description: string;
}

export interface GiftCardConfig {
  denominations: number[];
  expiryMonths: number;
  note: string;
}

export interface SubscriptionPlan {
  name: string;
  priceVnd: number;
  period: string; // e.g. "tuần", "tháng"
  description: string;
}
export interface SubscriptionConfig {
  plans: SubscriptionPlan[];
  note: string;
}

export interface CateringConfig {
  minGuests: number;
  leadDays: number;
  description: string;
}

export interface RewardItem {
  name: string;
  points: number;
  note: string;
}
export interface RewardsConfig {
  items: RewardItem[];
}

export const DEFAULT_REFERRAL: ReferralConfig = {
  referrerPoints: 50,
  refereePoints: 50,
  description:
    'Giới thiệu bạn bè — cả bạn và người được giới thiệu đều nhận điểm ' +
    'thưởng khi họ đặt đơn đầu tiên.',
};

export const DEFAULT_GIFT_CARD: GiftCardConfig = {
  denominations: [200000, 500000, 1000000],
  expiryMonths: 12,
  note: 'Thẻ quà tặng Banan — dùng để thanh toán đơn hàng trong thời hạn sử dụng.',
};

export const DEFAULT_SUBSCRIPTION: SubscriptionConfig = {
  plans: [],
  note: 'Nhận bánh tươi định kỳ — tiện lợi và ưu đãi hơn mua lẻ.',
};

export const DEFAULT_CATERING: CateringConfig = {
  minGuests: 20,
  leadDays: 3,
  description:
    'Đặt bánh & tráng miệng cho sự kiện, tiệc công ty, sinh nhật đông người. ' +
    'Để lại thông tin, chúng tôi sẽ liên hệ tư vấn và báo giá.',
};

export const DEFAULT_REWARDS: RewardsConfig = {
  items: [],
};

export const MARKETING_DEFAULTS = {
  referral: DEFAULT_REFERRAL,
  giftCard: DEFAULT_GIFT_CARD,
  subscription: DEFAULT_SUBSCRIPTION,
  catering: DEFAULT_CATERING,
  rewards: DEFAULT_REWARDS,
};

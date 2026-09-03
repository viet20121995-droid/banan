/// 2026 Mid-Autumn "Fullmoon Autumn" campaign: explicit VN-time window so
/// the theme retires itself after the festival period.
bool get fullmoonAutumnCampaignEnabled {
  final vnNow = DateTime.now().toUtc().add(const Duration(hours: 7));
  final day = DateTime.utc(vnNow.year, vnNow.month, vnNow.day);
  return !day.isBefore(DateTime.utc(2026, 9, 3)) &&
      day.isBefore(DateTime.utc(2026, 10, 1));
}

const fullmoonAutumnBannerAsset =
    'assets/campaigns/fullmoon-autumn-golden-kiwi.jpg';
const fullmoonAutumnParadeAsset =
    'assets/campaigns/fullmoon-autumn-lantern-parade.png';

/// Gold line-art (moon, clouds, star lanterns, carp, mooncakes) on the cream
/// page colour; fades to flat cream at the bottom so it only dresses the top
/// of every route.
const fullmoonAutumnPageBackgroundAsset =
    'assets/campaigns/fullmoon-autumn-page-bg.jpg';

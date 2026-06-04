import 'package:equatable/equatable.dart';

/// Admin-tunable promotional popup shown on the customer menu. `version`
/// is bumped on the backend when the admin wants every customer (even
/// those who previously dismissed) to see the popup again.
class PromoPopup extends Equatable {
  const PromoPopup({
    required this.isActive,
    required this.title,
    required this.body,
    required this.countdownSeconds,
    required this.version,
    this.imageUrl,
    this.ctaLabel,
    this.ctaUrl,
  });

  final bool isActive;
  final String title;
  final String body;
  final String? imageUrl;
  final String? ctaLabel;
  final String? ctaUrl;

  /// 0 = no auto-close (customer must tap X). Else the popup auto-closes
  /// after this many seconds with a visible countdown bar.
  final int countdownSeconds;

  /// Bumped by the admin to re-surface the popup for every device.
  final int version;

  /// Whether this popup should be displayed given the device's last seen
  /// version. Encapsulated here so the show-once logic lives in one
  /// place — used by the customer site.
  bool shouldShow({required int? lastSeenVersion}) {
    if (!isActive) return false;
    if (title.trim().isEmpty && body.trim().isEmpty) return false;
    if (lastSeenVersion == null) return true;
    return lastSeenVersion < version;
  }

  @override
  List<Object?> get props => [
        isActive,
        title,
        body,
        imageUrl,
        ctaLabel,
        ctaUrl,
        countdownSeconds,
        version,
      ];
}

import 'package:equatable/equatable.dart';

/// A home-page hero banner. `editable` is false for chain-wide banners
/// when viewed by a store merchant.
class HomeBanner extends Equatable {
  const HomeBanner({
    required this.id,
    required this.imageUrl,
    required this.sortOrder,
    required this.isActive,
    this.title,
    this.ctaUrl,
    this.chainWide = false,
    this.editable = true,
  });

  final String id;
  final String imageUrl;
  final String? title;
  final String? ctaUrl;
  final int sortOrder;
  final bool isActive;
  final bool chainWide;
  final bool editable;

  @override
  List<Object?> get props =>
      [id, imageUrl, title, ctaUrl, sortOrder, isActive, chainWide, editable];
}

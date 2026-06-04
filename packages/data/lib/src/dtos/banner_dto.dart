import 'package:banan_domain/banan_domain.dart';

class BannerDto {
  const BannerDto(this._json);

  factory BannerDto.fromJson(Map<String, dynamic> json) => BannerDto(json);
  final Map<String, dynamic> _json;

  HomeBanner toDomain() => HomeBanner(
        id: _json['id'] as String,
        imageUrl: _json['imageUrl'] as String,
        title: _json['title'] as String?,
        ctaUrl: _json['ctaUrl'] as String?,
        sortOrder: (_json['sortOrder'] as num?)?.toInt() ?? 0,
        isActive: _json['isActive'] as bool? ?? true,
        chainWide: _json['chainWide'] as bool? ?? false,
        editable: _json['editable'] as bool? ?? true,
      );
}

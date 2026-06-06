import 'package:banan_domain/banan_domain.dart';

/// Maps the enveloped campaign JSON (`{ data: {...} }` already unwrapped by
/// the API) into a [Campaign] domain entity.
class CampaignDto {
  const CampaignDto(this._json);

  factory CampaignDto.fromJson(Map<String, dynamic> json) => CampaignDto(json);
  final Map<String, dynamic> _json;

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Campaign toDomain() => Campaign(
        id: _json['id'] as String,
        type: CampaignType.fromWire(_json['type'] as String),
        name: _json['name'] as String,
        isActive: _json['isActive'] as bool? ?? true,
        priority: (_json['priority'] as num?)?.toInt() ?? 0,
        stackable: _json['stackable'] as bool? ?? false,
        startsAt: _parseDate(_json['startsAt']),
        endsAt: _parseDate(_json['endsAt']),
        config: (_json['config'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
        storeId: _json['storeId'] as String?,
        usageLimit: (_json['usageLimit'] as num?)?.toInt(),
        usedCount: (_json['usedCount'] as num?)?.toInt() ?? 0,
        perUserLimit: (_json['perUserLimit'] as num?)?.toInt(),
        createdAt:
            _parseDate(_json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt:
            _parseDate(_json['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

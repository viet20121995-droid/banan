/// View models for the CukCuk sync endpoints (`/internal/cukcuk/*`).
/// Records keep the raw CukCuk row in [data]; the table columns read from
/// it with fallbacks because field names vary per dataset.
library;

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v) : null;

class CukcukKindStatus {
  const CukcukKindStatus({
    required this.kind,
    required this.label,
    required this.count,
    required this.running,
    this.lastSyncAt,
    this.lastFetched = 0,
    this.lastError,
    this.lastErrorAt,
  });

  factory CukcukKindStatus.fromJson(Map<String, dynamic> j) => CukcukKindStatus(
        kind: j['kind'] as String,
        label: j['label'] as String? ?? j['kind'] as String,
        count: (j['count'] as num?)?.toInt() ?? 0,
        running: j['running'] as bool? ?? false,
        lastSyncAt: _date(j['lastSyncAt']),
        lastFetched: (j['lastFetched'] as num?)?.toInt() ?? 0,
        lastError: j['lastError'] as String?,
        lastErrorAt: _date(j['lastErrorAt']),
      );

  final String kind;
  final String label;
  final int count;
  final bool running;
  final DateTime? lastSyncAt;
  final int lastFetched;
  final String? lastError;
  final DateTime? lastErrorAt;
}

class CukcukStatus {
  const CukcukStatus({
    required this.configured,
    required this.kinds,
    this.domain,
  });

  factory CukcukStatus.fromJson(Map<String, dynamic> j) => CukcukStatus(
        configured: j['configured'] as bool? ?? false,
        domain: j['domain'] as String?,
        kinds: ((j['kinds'] as List?) ?? const [])
            .map((e) => CukcukKindStatus.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final bool configured;
  final String? domain;
  final List<CukcukKindStatus> kinds;
}

class CukcukSyncResult {
  const CukcukSyncResult({
    required this.kind,
    required this.fetched,
    this.error,
  });

  factory CukcukSyncResult.fromJson(Map<String, dynamic> j) => CukcukSyncResult(
        kind: j['kind'] as String,
        fetched: (j['fetched'] as num?)?.toInt() ?? 0,
        error: j['error'] as String?,
      );

  final String kind;
  final int fetched;
  final String? error;
}

class CukcukRecord {
  const CukcukRecord({
    required this.id,
    required this.kind,
    required this.externalId,
    required this.data,
    this.label,
    this.branchId,
    this.modifiedAt,
    this.syncedAt,
    this.linkedUserId,
  });

  factory CukcukRecord.fromJson(Map<String, dynamic> j) => CukcukRecord(
        id: j['id'] as String,
        kind: j['kind'] as String,
        externalId: j['externalId'] as String,
        label: j['label'] as String?,
        branchId: j['branchId'] as String?,
        modifiedAt: _date(j['modifiedAt']),
        syncedAt: _date(j['syncedAt']),
        linkedUserId: j['linkedUserId'] as String?,
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  final String id;
  final String kind;
  final String externalId;
  final String? label;
  final String? branchId;
  final DateTime? modifiedAt;
  final DateTime? syncedAt;

  /// Website account matched by phone (customers only).
  final String? linkedUserId;
  final Map<String, dynamic> data;

  /// First non-empty value among [keys] in the raw row, as text.
  String field(List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v == null) continue;
      if (v is String) {
        if (v.trim().isNotEmpty) return v.trim();
      } else if (v is num) {
        return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
      } else if (v is bool) {
        return v ? 'Có' : 'Không';
      }
    }
    return '';
  }
}

class CukcukPage {
  const CukcukPage({required this.items, required this.total, required this.page});
  final List<CukcukRecord> items;
  final int total;
  final int page;
}

class CukcukApplyResult {
  const CukcukApplyResult({required this.matched, required this.updated});
  factory CukcukApplyResult.fromJson(Map<String, dynamic> j) => CukcukApplyResult(
        matched: (j['matched'] as num?)?.toInt() ?? 0,
        updated: (j['updated'] as num?)?.toInt() ?? 0,
      );
  final int matched;
  final int updated;
}

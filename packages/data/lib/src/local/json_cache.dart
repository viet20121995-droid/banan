import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

/// Read-through JSON cache for API responses. Wraps a Hive box; values are
/// stored as the JSON-encoded body the API returned, alongside a sibling
/// `<key>__updatedAt` ISO-8601 timestamp.
///
/// Used by the catalog API to keep the menu browsable when the customer is
/// offline. Hive on web uses IndexedDB, on native uses local files.
class JsonCache {
  JsonCache(this._box);

  final Box<String> _box;

  static const _suffixUpdatedAt = '__updatedAt';

  /// Write [payload] under [key]. Anything `json.encode` accepts is fine —
  /// raw `List`/`Map` from `Dio` works directly.
  Future<void> write(String key, Object payload) async {
    try {
      await _box.put(key, json.encode(payload));
      await _box.put(
        '$key$_suffixUpdatedAt',
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('JsonCache.write($key) failed: $e');
    }
  }

  /// Returns the previously cached value (decoded as `dynamic`) or `null` if
  /// nothing has ever been cached for [key].
  CachedValue? read(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      final updatedRaw = _box.get('$key$_suffixUpdatedAt');
      return CachedValue(
        payload: json.decode(raw),
        updatedAt:
            updatedRaw == null ? null : DateTime.tryParse(updatedRaw),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('JsonCache.read($key) failed: $e');
      return null;
    }
  }

  Future<void> clear(String key) async {
    await _box.delete(key);
    await _box.delete('$key$_suffixUpdatedAt');
  }
}

@immutable
class CachedValue {
  const CachedValue({required this.payload, this.updatedAt});

  final dynamic payload;
  final DateTime? updatedAt;
}

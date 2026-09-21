import 'package:banan_domain/banan_domain.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens in platform secure storage, with an in-memory fallback: browsers
/// that block storage (Safari "block all cookies", locked-down in-app webviews
/// — Zalo, Instagram, Facebook) make the plugin THROW, and an uncaught throw
/// here used to break every API call, guest checkout included. With the
/// fallback the session simply lasts for the tab.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _accessKey = 'banan.auth.access';
  static const _refreshKey = 'banan.auth.refresh';

  final FlutterSecureStorage _storage;
  StoredTokens? _memory;

  @override
  Future<StoredTokens?> read() async {
    try {
      final access = await _storage.read(key: _accessKey);
      final refresh = await _storage.read(key: _refreshKey);
      if (access == null || refresh == null) return _memory;
      return StoredTokens(accessToken: access, refreshToken: refresh);
    } catch (_) {
      return _memory;
    }
  }

  @override
  Future<void> write(StoredTokens tokens) async {
    _memory = tokens;
    try {
      await _storage.write(key: _accessKey, value: tokens.accessToken);
      await _storage.write(key: _refreshKey, value: tokens.refreshToken);
    } catch (_) {
      // storage blocked — the in-memory copy carries the session
    }
  }

  @override
  Future<void> clear() async {
    _memory = null;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {
      // storage blocked — nothing persisted to remove
    }
  }
}

import 'package:banan_domain/banan_domain.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _accessKey = 'banan.auth.access';
  static const _refreshKey = 'banan.auth.refresh';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredTokens?> read() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    return StoredTokens(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> write(StoredTokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

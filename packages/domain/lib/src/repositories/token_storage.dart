import '../entities/auth_session.dart';

/// Persistent token storage. On mobile this is Keychain / Keystore via
/// `flutter_secure_storage`; on web, an encrypted IndexedDB shim.
abstract class TokenStorage {
  Future<StoredTokens?> read();
  Future<void> write(StoredTokens tokens);
  Future<void> clear();
}

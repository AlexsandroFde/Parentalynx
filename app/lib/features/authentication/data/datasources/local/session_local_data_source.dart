import '../../../../../core/constants/storage_keys.dart';
import '../../../../../core/network/session_credentials.dart';
import '../../../../../core/storage/secure_store.dart';

/// Credenciais da sessao gravadas neste aparelho: token (via [SessionCredentials], que o
/// cliente da API le), e-mail e identificador da sessao.
class SessionLocalDataSource {
  const SessionLocalDataSource({required this._credentials, required this._store});

  final SessionCredentials _credentials;
  final SecureStore _store;

  bool get hasToken => _credentials.hasToken;

  Stream<void> get rejections => _credentials.rejections;

  Future<void> save({
    required String token,
    required String email,
    required String sessionId,
  }) async {
    await _credentials.save(token);
    await _store.write(StorageKeys.guardianEmail, email);
    await _store.write(StorageKeys.guardianSessionId, sessionId);
  }

  Future<void> clear() async {
    await _credentials.clear();
    await _store.delete(StorageKeys.guardianEmail);
    await _store.delete(StorageKeys.guardianSessionId);
  }

  Future<String?> storedEmail() => _store.read(StorageKeys.guardianEmail);
}

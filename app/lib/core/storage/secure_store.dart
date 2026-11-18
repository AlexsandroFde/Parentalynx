import '../platform/native_api.g.dart';

/// Armazenamento de segredos (tokens). A implementacao real cifra com o Android Keystore.
abstract interface class SecureStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Implementacao sobre a ponte nativa.
class NativeSecureStore implements SecureStore {
  NativeSecureStore(this._api);

  final SecureStorageApi _api;

  @override
  Future<String?> read(String key) => _api.read(key);

  @override
  Future<void> write(String key, String value) => _api.write(key, value);

  @override
  Future<void> delete(String key) => _api.delete(key);
}

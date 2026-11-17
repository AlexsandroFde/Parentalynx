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

/// Implementacao em memoria para testes.
class InMemorySecureStore implements SecureStore {
  InMemorySecureStore([Map<String, String>? initial]) : _values = <String, String>{...?initial};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

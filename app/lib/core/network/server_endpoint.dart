import '../constants/storage_keys.dart';
import '../storage/secure_store.dart';
import '../utils/observable_value.dart';

/// Endereco do servidor em uso.
///
/// Fica em memoria para as chamadas e gravado no armazenamento seguro para as proximas
/// aberturas. O [ApiClient] le o valor a cada chamada, entao uma troca vale na hora.
class ServerEndpoint {
  ServerEndpoint({required this._store, required String initialUrl})
    : _url = ObservableValue<String>.seeded(normalize(initialUrl));

  final SecureStore _store;
  final ObservableValue<String> _url;

  /// Endereco atual, sem barra no final. Vazio quando o build nao trouxe um e ninguem
  /// configurou.
  String get url => _url.value;

  /// Endereco atual seguido das trocas.
  Stream<String> get changes => _url.stream;

  /// Grava o novo endereco. A validacao (HTTPS em producao) e regra de negocio e acontece
  /// antes, no caso de uso que chama este metodo.
  Future<void> update(String url) async {
    final String clean = normalize(url);
    await _store.write(StorageKeys.serverUrl, clean);
    _url.add(clean);
  }

  static String normalize(String url) {
    final String trimmed = url.trim();
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }
}

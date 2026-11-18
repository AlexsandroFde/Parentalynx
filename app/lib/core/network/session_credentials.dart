import 'dart:async';

import '../constants/storage_keys.dart';
import '../storage/secure_store.dart';

/// Token da sessao do responsavel e o aviso de sessao recusada pelo servidor.
///
/// O token fica em memoria para as chamadas e cifrado no armazenamento seguro para as
/// proximas aberturas e para o worker nativo de alertas, que le a mesma chave.
class SessionCredentials {
  SessionCredentials({required this._store, String? initialToken}) : _token = initialToken;

  final SecureStore _store;
  final StreamController<void> _rejections = StreamController<void>.broadcast();
  String? _token;

  /// Token atual, ou nulo quando nao ha sessao.
  String? get token => _token;

  bool get hasToken => _token != null;

  Future<void> save(String token) async {
    await _store.write(StorageKeys.guardianSessionToken, token);
    _token = token;
  }

  Future<void> clear() async {
    _token = null;
    await _store.delete(StorageKeys.guardianSessionToken);
  }

  /// Chamado pelo cliente da API quando o servidor recusa a sessao (`session_expired`).
  void reportRejected() {
    if (_token != null && !_rejections.isClosed) {
      _rejections.add(null);
    }
  }

  /// Avisos de sessao recusada. Quem cuida da sessao encerra a sessao local ao receber.
  Stream<void> get rejections => _rejections.stream;

  Future<void> dispose() => _rejections.close();
}

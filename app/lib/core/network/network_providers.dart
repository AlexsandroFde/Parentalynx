import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../platform/native_providers.dart';
import 'api_client.dart';

final Provider<http.Client> httpClientProvider = Provider<http.Client>((Ref ref) {
  final http.Client client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Endereco do servidor lido do armazenamento antes de o app subir.
final Provider<String> initialServerUrlProvider = Provider<String>(
  (Ref ref) => AppConfig.defaultServerUrl,
);

/// Token de sessao do responsavel lido do armazenamento antes de o app subir.
final Provider<String?> initialSessionTokenProvider = Provider<String?>((Ref ref) => null);

/// Endereco do servidor em uso.
final NotifierProvider<ServerUrlController, String> serverUrlProvider =
    NotifierProvider<ServerUrlController, String>(ServerUrlController.new);

class ServerUrlController extends Notifier<String> {
  @override
  String build() => ref.watch(initialServerUrlProvider);

  /// Grava o novo endereco. Quem chama deve validar antes com
  /// [AppConfig.isAcceptableServerUrl].
  Future<void> set(String url) async {
    final String clean = _normalize(url);
    await ref.read(secureStoreProvider).write(StorageKeys.serverUrl, clean);
    state = clean;
  }

  static String _normalize(String url) {
    final String trimmed = url.trim();
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }
}

/// Token da sessao do responsavel. Nulo quando nao ha sessao.
///
/// Fica em memoria para as chamadas e cifrado no armazenamento seguro para as proximas
/// aberturas e para o worker nativo de alertas.
final NotifierProvider<SessionTokenController, String?> sessionTokenProvider =
    NotifierProvider<SessionTokenController, String?>(SessionTokenController.new);

class SessionTokenController extends Notifier<String?> {
  @override
  String? build() => ref.watch(initialSessionTokenProvider);

  Future<void> set(String token) async {
    await ref.read(secureStoreProvider).write(StorageKeys.guardianSessionToken, token);
    state = token;
  }

  Future<void> clear() async {
    await ref.read(secureStoreProvider).delete(StorageKeys.guardianSessionToken);
    state = null;
  }
}

/// Conta quantas vezes o servidor recusou a sessao atual (`session_expired`). Quem cuida da
/// sessao observa este valor e encerra a sessao local quando ele muda.
final NotifierProvider<SessionInvalidatedSignal, int> sessionInvalidatedProvider =
    NotifierProvider<SessionInvalidatedSignal, int>(SessionInvalidatedSignal.new);

class SessionInvalidatedSignal extends Notifier<int> {
  @override
  int build() => 0;

  void signal() {
    state = state + 1;
  }
}

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  return ApiClient(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: () => ref.read(serverUrlProvider),
    sessionToken: () => ref.read(sessionTokenProvider),
    onSessionInvalid: () => ref.read(sessionInvalidatedProvider.notifier).signal(),
  );
});

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../../core/logging/app_logger.dart';
import '../../core/navigation/launch_action.dart';
import '../../core/network/api_client.dart';
import '../../core/network/server_endpoint.dart';
import '../../core/network/session_credentials.dart';
import '../../core/platform/native_api.g.dart';
import '../../core/platform/native_events.dart';
import '../../core/platform/native_launch_actions.dart';
import '../../core/storage/local_preferences.dart';
import '../../core/storage/secure_store.dart';
import '../../core/time/clock.dart';
import '../../shared/services/share_service.dart';

/// Valores lidos antes do primeiro quadro (bootstrap) e entregues ao conteiner.
final class CoreBootValues {
  const CoreBootValues({required this.serverUrl, this.sessionToken});

  /// Endereco do servidor: `AppConfig.serverUrl` no app, o servidor falso nos testes.
  final String serverUrl;

  /// Token da sessao do responsavel gravado, quando ha.
  final String? sessionToken;
}

/// Registra a infraestrutura compartilhada: ponte nativa, armazenamento, rede, relogio,
/// registro e servicos de interface.
///
/// Os testes registram dubles no lugar destes (ver `test/support/test_dependencies.dart`).
void registerCoreModule(GetIt di, CoreBootValues values) {
  // Ponte nativa (codigo gerado pelo Pigeon). So a camada de dados usa estas classes.
  di
    ..registerLazySingleton<AppModeApi>(AppModeApi.new)
    ..registerLazySingleton<SecureStorageApi>(SecureStorageApi.new)
    ..registerLazySingleton<DeviceApi>(DeviceApi.new)
    ..registerLazySingleton<ChildAgentApi>(ChildAgentApi.new)
    ..registerLazySingleton<BrowserApi>(BrowserApi.new)
    ..registerLazySingleton<GuardianNativeApi>(GuardianNativeApi.new)
    ..registerLazySingleton<NativeEventsDispatcher>(
      () => NativeEventsDispatcher()..attach(),
      dispose: (NativeEventsDispatcher events) async {
        events.detach();
        await events.dispose();
      },
    );

  // Armazenamento, relogio e registro.
  di
    ..registerLazySingleton<SecureStore>(() => NativeSecureStore(di<SecureStorageApi>()))
    ..registerLazySingleton<LocalPreferences>(() => const SharedPreferencesStore())
    ..registerLazySingleton<Clock>(() => const SystemClock())
    ..registerLazySingleton<AppLogger>(() => const DeveloperLogger());

  registerNetworkModule(di, values);

  // Acoes de abertura (notificacao, tela de bloqueio nativa).
  di.registerLazySingleton<LaunchActionSource>(
    () =>
        NativeLaunchActionSource(api: di<AppModeApi>(), events: di<NativeEventsDispatcher>())
          ..start(),
    dispose: (LaunchActionSource source) async {
      if (source is NativeLaunchActionSource) {
        await source.dispose();
      }
    },
  );

  // Servicos de interface entregues as telas pela arvore de widgets.
  di.registerLazySingleton<ShareService>(() => const SystemShareService());
}

/// Rede: endereco do servidor, credenciais da sessao e cliente da API.
///
/// Separado para os testes trocarem so o cliente HTTP.
void registerNetworkModule(GetIt di, CoreBootValues values, {http.Client? httpClient}) {
  di
    ..registerLazySingleton<http.Client>(
      () => httpClient ?? http.Client(),
      dispose: (http.Client client) => client.close(),
    )
    ..registerLazySingleton<ServerEndpoint>(() => ServerEndpoint(values.serverUrl))
    ..registerLazySingleton<SessionCredentials>(
      () => SessionCredentials(store: di<SecureStore>(), initialToken: values.sessionToken),
      dispose: (SessionCredentials credentials) => credentials.dispose(),
    )
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(
        httpClient: di<http.Client>(),
        baseUrl: () => di<ServerEndpoint>().url,
        sessionToken: () => di<SessionCredentials>().token,
        onSessionInvalid: () => di<SessionCredentials>().reportRejected(),
      ),
    );
}

import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/app/di/core_module.dart';
import 'package:parentalynx/core/logging/app_logger.dart';
import 'package:parentalynx/core/navigation/launch_action.dart';
import 'package:parentalynx/core/platform/native_api.g.dart';
import 'package:parentalynx/core/platform/native_events.dart';
import 'package:parentalynx/core/storage/local_preferences.dart';
import 'package:parentalynx/core/storage/secure_store.dart';
import 'package:parentalynx/core/time/clock.dart';
import 'package:parentalynx/features/authentication/authentication_module.dart';
import 'package:parentalynx/features/authentication/domain/services/i_elevation_prompter.dart';
import 'package:parentalynx/features/child_device/child_device_module.dart';
import 'package:parentalynx/features/device_policy/device_policy_module.dart';
import 'package:parentalynx/features/device_sync/device_sync_module.dart';
import 'package:parentalynx/features/device_sync/domain/repositories/i_realtime_repository.dart';
import 'package:parentalynx/features/server_config/server_config_module.dart';
import 'package:parentalynx/features/user_role/domain/entities/user_role.dart';
import 'package:parentalynx/features/user_role/user_role_module.dart';
import 'package:parentalynx/shared/services/share_service.dart';

import 'fake_backend.dart';
import 'fakes.dart';
import 'native_doubles.dart';

/// Conteiner de dependencias para testes.
///
/// Usa os modulos reais (casos de uso, repositorios, BLoCs) com o nucleo trocado por dubles:
/// servidor falso, ponte nativa simulada, armazenamento em memoria, relogio controlado e canal
/// em tempo real controlado. Ja registra os modulos de base (perfil, servidor, autenticacao,
/// sincronizacao, aparelhos e politica); cada teste registra os modulos da funcionalidade
/// testada em [di].
class TestDependencies {
  TestDependencies({
    FakeBackend? backend,
    NativeDoubles? native,
    this.role = UserRole.unset,
    this.serverUrl = 'https://servidor.teste',
    this.sessionToken,
    InMemorySecureStore? secureStore,
    InMemoryLocalPreferences? preferences,
    FakeClock? clock,
    FakeShareService? share,
    FakeRealtimeRepository? realtime,
    FakeLaunchActionSource? launchActions,
    IElevationPrompter? elevationPrompter,
    GlobalKey<NavigatorState>? navigatorKey,
  }) : backend = backend ?? FakeBackend(),
       native = native ?? NativeDoubles(),
       secureStore = secureStore ?? InMemorySecureStore(),
       preferences = preferences ?? InMemoryLocalPreferences(),
       clock = clock ?? FakeClock(),
       share = share ?? FakeShareService(),
       realtime = realtime ?? FakeRealtimeRepository(),
       launchActions = launchActions ?? FakeLaunchActionSource(),
       navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>() {
    _register(elevationPrompter);
  }

  final GetIt di = GetIt.asNewInstance()..allowReassignment = true;
  final FakeBackend backend;
  final NativeDoubles native;
  final UserRole role;
  final String serverUrl;
  final String? sessionToken;
  final InMemorySecureStore secureStore;
  final InMemoryLocalPreferences preferences;
  final FakeClock clock;
  final FakeShareService share;
  final FakeRealtimeRepository realtime;
  final FakeLaunchActionSource launchActions;

  /// Navegador raiz usado pelo pedido de senha. Passe para o `MaterialApp` do teste.
  final GlobalKey<NavigatorState> navigatorKey;

  void _register(IElevationPrompter? elevationPrompter) {
    di
      ..registerSingleton<AppModeApi>(native.mode)
      ..registerSingleton<DeviceApi>(native.device)
      ..registerSingleton<GuardianNativeApi>(native.guardian)
      ..registerSingleton<ChildAgentApi>(native.agent)
      ..registerSingleton<BrowserApi>(native.browser)
      ..registerSingleton<NativeEventsDispatcher>(NativeEventsDispatcher())
      ..registerSingleton<SecureStore>(secureStore)
      ..registerSingleton<LocalPreferences>(preferences)
      ..registerSingleton<Clock>(clock)
      ..registerSingleton<AppLogger>(const SilentLogger())
      ..registerSingleton<ShareService>(share)
      ..registerSingleton<LaunchActionSource>(launchActions);
    registerNetworkModule(
      di,
      CoreBootValues(serverUrl: serverUrl, sessionToken: sessionToken),
      httpClient: backend.client,
    );

    registerUserRoleModule(di, initialRole: role);
    registerServerConfigModule(di, allowInsecureHttp: true);
    registerAuthenticationModule(di, navigatorKey: navigatorKey);
    registerDeviceSyncModule(di);
    registerChildDeviceModule(di);
    registerDevicePolicyModule(di);

    // Sem WebSocket real nos testes.
    di.registerSingleton<IRealtimeRepository>(realtime);
    if (elevationPrompter != null) {
      di.registerSingleton<IElevationPrompter>(elevationPrompter);
    }
  }

  /// Esquece as instancias registradas, sem chamar o descarte delas.
  ///
  /// Cada teste tem o seu conteiner, entao nada vaza entre testes. O descarte nao e chamado
  /// porque, dentro de um `testWidgets` (relogio simulado), fechar um BLoC que ainda escuta
  /// fluxos nunca termina: o `cancel()` das assinaturas devolve um futuro da zona raiz, cuja
  /// continuacao cai na zona simulada e nao e mais processada. Os BLoCs das telas sao fechados
  /// pelos seus `BlocProvider` ao desmontar a arvore, o que nao depende disso.
  Future<void> dispose() => di.reset(dispose: false);
}

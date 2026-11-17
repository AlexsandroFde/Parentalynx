import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_failure.dart';
import '../storage/secure_store.dart';
import 'native_api.g.dart';

export 'native_api.g.dart'
    show
        AdminAuthOutcome,
        AdminAuthResult,
        AgentStatus,
        AppMode,
        BrowserConfig,
        ChildCredentials,
        LockState,
        ManagementMode,
        NativeAppInfo,
        NativeDeviceInfo,
        PermissionSnapshot,
        SyncOutcome,
        TimeRequestInfo,
        UrlDecision,
        UsageEntry;

// Provedores da ponte nativa. Os testes trocam cada um por um duble com `overrides`.

final Provider<AppModeApi> appModeApiProvider = Provider<AppModeApi>((Ref ref) => AppModeApi());

final Provider<SecureStorageApi> secureStorageApiProvider = Provider<SecureStorageApi>(
  (Ref ref) => SecureStorageApi(),
);

final Provider<DeviceApi> deviceApiProvider = Provider<DeviceApi>((Ref ref) => DeviceApi());

final Provider<ChildAgentApi> childAgentApiProvider = Provider<ChildAgentApi>(
  (Ref ref) => ChildAgentApi(),
);

final Provider<BrowserApi> browserApiProvider = Provider<BrowserApi>((Ref ref) => BrowserApi());

final Provider<GuardianNativeApi> guardianNativeApiProvider = Provider<GuardianNativeApi>(
  (Ref ref) => GuardianNativeApi(),
);

final Provider<SecureStore> secureStoreProvider = Provider<SecureStore>(
  (Ref ref) => NativeSecureStore(ref.watch(secureStorageApiProvider)),
);

/// Modo lido do lado nativo antes de o app subir. Sobrescrito no bootstrap.
final Provider<AppMode> initialAppModeProvider = Provider<AppMode>(
  (Ref ref) => throw StateError('initialAppModeProvider deve ser sobrescrito no bootstrap'),
);

/// Modo de funcionamento do app (responsavel ou crianca).
final NotifierProvider<AppModeController, AppMode> appModeProvider =
    NotifierProvider<AppModeController, AppMode>(AppModeController.new);

class AppModeController extends Notifier<AppMode> {
  @override
  AppMode build() => ref.watch(initialAppModeProvider);

  /// Troca o modo. O lado nativo recusa sair do modo crianca sem autenticacao do responsavel.
  Future<void> setMode(AppMode mode) async {
    try {
      await ref.read(appModeApiProvider).setMode(mode);
    } on PlatformException catch (error) {
      throw UnexpectedFailure(
        error.message ?? 'Não foi possível trocar o modo do aplicativo.',
        error,
      );
    }
    state = mode;
  }
}

/// Liga os avisos do lado nativo aos provedores. Deve ser observado pela raiz de cada app
/// (principal e navegador) para que os avisos cheguem enquanto a interface estiver viva.
final Provider<void> nativeEventsBindingProvider = Provider<void>((Ref ref) {
  NativeEventsApi.setUp(
    _NativeEventsHandler(
      onAction: (String action) => ref.read(launchActionProvider.notifier).receive(action),
      onUrl: (String url) => ref.read(browserOpenUrlProvider.notifier).receive(url),
    ),
  );
  ref.onDispose(() => NativeEventsApi.setUp(null));
});

class _NativeEventsHandler implements NativeEventsApi {
  const _NativeEventsHandler({required this.onAction, required this.onUrl});

  final void Function(String action) onAction;
  final void Function(String url) onUrl;

  @override
  void onLaunchAction(String action) => onAction(action);

  @override
  void onOpenUrl(String url) => onUrl(url);
}

/// Acao pedida por quem abriu o app (notificacao ou tela de bloqueio).
///
/// Valores: `alerts`, `guardian_area`, `child_home`, `permissions`. Quem trata a acao chama
/// [LaunchActionController.consume] para nao trata-la duas vezes.
final NotifierProvider<LaunchActionController, String?> launchActionProvider =
    NotifierProvider<LaunchActionController, String?>(LaunchActionController.new);

class LaunchActionController extends Notifier<String?> {
  @override
  String? build() {
    Future<void>.microtask(_loadInitial);
    return null;
  }

  Future<void> _loadInitial() async {
    try {
      final String? action = await ref.read(appModeApiProvider).consumeLaunchAction();
      if (action != null && ref.mounted) {
        state = action;
      }
    } on PlatformException {
      // Sem acao de abertura. Nada a fazer.
    }
  }

  /// Chamado quando a atividade ja aberta recebe uma nova acao.
  void receive(String action) {
    state = action;
  }

  void consume() {
    state = null;
  }
}

/// Endereco que o navegador gerenciado deve abrir (link tocado em outro app).
///
/// Quem carrega o endereco chama [BrowserOpenUrlController.consume].
final NotifierProvider<BrowserOpenUrlController, String?> browserOpenUrlProvider =
    NotifierProvider<BrowserOpenUrlController, String?>(BrowserOpenUrlController.new);

class BrowserOpenUrlController extends Notifier<String?> {
  @override
  String? build() {
    Future<void>.microtask(_loadInitial);
    return null;
  }

  Future<void> _loadInitial() async {
    try {
      final String? url = await ref.read(browserApiProvider).consumeInitialUrl();
      if (url != null && ref.mounted) {
        state = url;
      }
    } on PlatformException {
      // O navegador foi aberto sem endereco inicial.
    }
  }

  /// Chamado quando o navegador ja aberto recebe um novo endereco.
  void receive(String url) {
    state = url;
  }

  void consume() {
    state = null;
  }
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/platform/native_api.g.dart' show GuardianNativeApi;
import '../../../../core/platform/native_providers.dart';
import '../../../../core/storage/secure_store.dart';
import '../../shell/data/local_prefs.dart';
import '../data/api_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/guardian_account.dart';
import 'app_lock.dart';

/// Estado da sessao do responsavel neste aparelho.
sealed class GuardianSession {
  const GuardianSession();
}

/// Nao ha sessao. [notice] explica por que a sessao anterior acabou, quando for o caso.
final class GuardianSignedOut extends GuardianSession {
  const GuardianSignedOut({this.notice});

  final String? notice;
}

/// Ha sessao, mas o painel esta bloqueado e pede a senha administrativa.
final class GuardianLocked extends GuardianSession {
  const GuardianLocked({this.account});

  /// Conta conhecida, quando o bloqueio aconteceu com o app ja aberto.
  final GuardianAccount? account;
}

/// Sessao aberta e painel desbloqueado.
final class GuardianReady extends GuardianSession {
  const GuardianReady({required this.account, required this.session, this.pendingRecoveryKey});

  final GuardianAccount account;
  final GuardianSessionInfo session;

  /// Chave de recuperacao recem-gerada que ainda precisa ser mostrada e confirmada.
  final String? pendingRecoveryKey;
}

/// Sessao do responsavel: login, bloqueio do app e encerramento.
///
/// O roteador observa este provedor para decidir entre as telas de conta, a tela de bloqueio
/// e o painel.
final NotifierProvider<GuardianSessionController, GuardianSession> guardianSessionProvider =
    NotifierProvider<GuardianSessionController, GuardianSession>(GuardianSessionController.new);

class GuardianSessionController extends Notifier<GuardianSession> {
  DateTime? _backgroundedAt;

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  SecureStore get _store => ref.read(secureStoreProvider);

  @override
  GuardianSession build() {
    ref.listen<int>(sessionInvalidatedProvider, (int? previous, int next) {
      if (previous != null && previous != next) {
        _onSessionInvalidated();
      }
    });
    // Mantem a preferencia de bloqueio carregada desde o inicio.
    ref.listen<AppLockTimeout>(appLockTimeoutProvider, (AppLockTimeout? _, AppLockTimeout _) {});
    final AppLifecycleListener lifecycle = AppLifecycleListener(onStateChange: handleLifecycle);
    ref.onDispose(lifecycle.dispose);

    // Com token gravado, a abertura a frio sempre comeca bloqueada.
    return ref.read(sessionTokenProvider) == null
        ? const GuardianSignedOut()
        : const GuardianLocked();
  }

  Future<void> register({
    required String email,
    required String displayName,
    required String password,
    required String deviceName,
  }) async {
    final AuthResult result = await _repository.register(
      email: email,
      displayName: displayName,
      password: password,
      deviceName: deviceName,
    );
    await _startSession(result);
  }

  Future<void> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final AuthResult result = await _repository.login(
      email: email,
      password: password,
      deviceName: deviceName,
    );
    await _startSession(result);
  }

  /// Troca a senha com a chave de recuperacao e abre uma sessao nova. A nova chave fica
  /// pendente de confirmacao.
  Future<void> recover({
    required String email,
    required String recoveryKey,
    required String newPassword,
    required String deviceName,
  }) async {
    final AuthResult result = await _repository.recover(
      email: email,
      recoveryKey: recoveryKey,
      newPassword: newPassword,
      deviceName: deviceName,
    );
    await _startSession(result);
  }

  /// Desbloqueia o painel. A verificacao da senha e a propria elevacao da sessao.
  Future<void> unlock(String password) async {
    await _repository.elevate(password);
    final GuardianProfile profile = await _repository.me();
    if (!ref.mounted || state is GuardianSignedOut) {
      return;
    }
    state = GuardianReady(account: profile.account, session: profile.session);
    _enableAlertPolling();
  }

  /// A pessoa confirmou que guardou a chave de recuperacao.
  void acknowledgeRecoveryKey() {
    final GuardianSession current = state;
    if (current is GuardianReady && current.pendingRecoveryKey != null) {
      state = GuardianReady(account: current.account, session: current.session);
    }
  }

  /// Bloqueia o painel agora.
  void lockNow() {
    final GuardianSession current = state;
    if (current is GuardianReady && current.pendingRecoveryKey == null) {
      state = GuardianLocked(account: current.account);
    }
  }

  /// Atualiza a conta em memoria depois de uma alteracao de perfil ou de preferencias.
  void updateAccount(GuardianAccount account) {
    final GuardianSession current = state;
    if (current is GuardianReady) {
      state = GuardianReady(
        account: account,
        session: current.session,
        pendingRecoveryKey: current.pendingRecoveryKey,
      );
    }
  }

  /// Recarrega a conta do servidor. Falhas sao ignoradas: os dados em memoria continuam.
  Future<void> refreshAccount() async {
    if (state is! GuardianReady) {
      return;
    }
    try {
      final GuardianProfile profile = await _repository.me();
      final GuardianSession current = state;
      if (ref.mounted && current is GuardianReady) {
        state = GuardianReady(
          account: profile.account,
          session: profile.session,
          pendingRecoveryKey: current.pendingRecoveryKey,
        );
      }
    } on AppFailure {
      // Sem rede ou sessao recusada. O segundo caso e tratado pelo aviso de sessao invalida.
    }
  }

  /// Encerra a sessao no servidor (se der) e neste aparelho.
  Future<void> signOut() async {
    try {
      await _repository.logout();
    } on AppFailure {
      // Sem rede: a sessao local e encerrada do mesmo jeito.
    }
    await _clearLocal();
  }

  /// Encerra a sessao local depois que a conta foi excluida no servidor.
  Future<void> onAccountDeleted() =>
      _clearLocal(notice: 'Sua conta e todos os dados foram excluídos.');

  /// Reage a mudanca de estado do aplicativo (primeiro plano e segundo plano).
  @visibleForTesting
  void handleLifecycle(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _backgroundedAt ??= ref.read(guardianClockProvider)();
      case AppLifecycleState.resumed:
        final DateTime? since = _backgroundedAt;
        _backgroundedAt = null;
        if (since == null) {
          return;
        }
        final GuardianSession current = state;
        // Enquanto a chave de recuperacao nao foi confirmada o painel nao bloqueia, para a
        // pessoa nao perder a chave ao sair para guarda-la.
        if (current is! GuardianReady || current.pendingRecoveryKey != null) {
          return;
        }
        final Duration away = ref.read(guardianClockProvider)().difference(since);
        if (away >= ref.read(appLockTimeoutProvider).duration) {
          state = GuardianLocked(account: current.account);
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _startSession(AuthResult result) async {
    await ref.read(sessionTokenProvider.notifier).set(result.token);
    await _store.write(StorageKeys.guardianEmail, result.account.email);
    await _store.write(StorageKeys.guardianSessionId, result.session.id);
    if (!ref.mounted) {
      return;
    }
    state = GuardianReady(
      account: result.account,
      session: result.session,
      pendingRecoveryKey: result.recoveryKey,
    );
    _enableAlertPolling();
  }

  void _onSessionInvalidated() {
    if (state is GuardianSignedOut) {
      return;
    }
    unawaited(_clearLocal(notice: 'Sua sessão foi encerrada. Entre de novo para continuar.'));
  }

  Future<void> _clearLocal({String? notice}) async {
    _backgroundedAt = null;
    // O estado muda primeiro, para o roteador sair do painel antes das limpezas assincronas.
    state = GuardianSignedOut(notice: notice);
    _disableAlertPolling();
    await ref.read(sessionTokenProvider.notifier).clear();
    await _store.delete(StorageKeys.guardianEmail);
    await _store.delete(StorageKeys.guardianSessionId);
  }

  void _enableAlertPolling() {
    final String serverUrl = ref.read(serverUrlProvider);
    final GuardianNativeApi api = ref.read(guardianNativeApiProvider);
    unawaited(_ignoringBridgeErrors(() => api.enableAlertPolling(serverUrl)));
  }

  void _disableAlertPolling() {
    final GuardianNativeApi api = ref.read(guardianNativeApiProvider);
    unawaited(_ignoringBridgeErrors(api.disableAlertPolling));
  }

  /// A busca de alertas em segundo plano e um reforco. Se a ponte nativa falhar, o painel
  /// continua funcionando com os alertas em tempo real.
  static Future<void> _ignoringBridgeErrors(Future<void> Function() call) async {
    try {
      await call();
    } on PlatformException {
      // Ver comentario acima.
    }
  }
}

/// E-mail da conta gravado no ultimo login, para a tela de bloqueio mostrar quem esta
/// conectado.
final FutureProvider<String?> storedGuardianEmailProvider = FutureProvider<String?>(
  (Ref ref) => ref.watch(secureStoreProvider).read(StorageKeys.guardianEmail),
);

/// Nome deste aparelho para identificar a sessao. Vem do sistema, com um padrao de reserva.
final FutureProvider<String> guardianDeviceNameProvider = FutureProvider<String>((Ref ref) async {
  try {
    final NativeDeviceInfo info = await ref.watch(deviceApiProvider).getDeviceInfo();
    return info.name.trim().isEmpty ? 'Aparelho do responsável' : info.name.trim();
  } on PlatformException {
    return 'Aparelho do responsável';
  }
});

/// Conta do responsavel quando o painel esta aberto, ou nulo.
final Provider<GuardianAccount?> guardianAccountProvider = Provider<GuardianAccount?>((Ref ref) {
  final GuardianSession session = ref.watch(guardianSessionProvider);
  return session is GuardianReady ? session.account : null;
});

/// Local onde a pessoa estava quando o painel bloqueou, para voltar depois de desbloquear.
class GuardianReturnLocation {
  String? _location;

  void remember(String location) {
    _location = location;
  }

  /// Devolve o local guardado e o esquece.
  String? take() {
    final String? location = _location;
    _location = null;
    return location;
  }
}

final Provider<GuardianReturnLocation> guardianReturnLocationProvider =
    Provider<GuardianReturnLocation>((Ref ref) => GuardianReturnLocation());

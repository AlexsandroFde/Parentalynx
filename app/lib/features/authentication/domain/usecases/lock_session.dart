import '../entities/app_lock_timeout.dart';
import '../entities/guardian_session.dart';
import '../repositories/i_app_lock_repository.dart';
import '../repositories/i_session_repository.dart';

/// Bloqueia o painel.
///
/// Enquanto a chave de recuperacao recem-gerada nao foi confirmada o painel nao bloqueia,
/// para a pessoa nao perder a chave ao sair do app para guarda-la.
class LockSession {
  const LockSession({required this._session, required this._preferences});

  final ISessionRepository _session;
  final IAppLockRepository _preferences;

  /// Bloqueia agora (acao "Bloquear o painel").
  void call() {
    if (_canLock(_session.current)) {
      _session.lock();
    }
  }

  /// Bloqueia se o app ficou em segundo plano pelo menos o tempo escolhido pelo responsavel.
  /// Devolve verdadeiro quando bloqueou.
  Future<bool> afterInactivity(Duration away) async {
    if (!_canLock(_session.current)) {
      return false;
    }
    final AppLockTimeout timeout = await _preferences.read();
    if (away < timeout.duration || !_canLock(_session.current)) {
      return false;
    }
    _session.lock();
    return true;
  }

  static bool _canLock(GuardianSessionState state) {
    return state is SessionOpen && state.pendingRecoveryKey == null;
  }
}

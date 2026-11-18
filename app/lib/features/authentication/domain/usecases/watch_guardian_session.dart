import '../entities/guardian_session.dart';
import '../repositories/i_session_repository.dart';

/// Situacao da sessao seguida das mudancas, e os avisos de sessao recusada pelo servidor.
class WatchGuardianSession {
  const WatchGuardianSession(this._session);

  final ISessionRepository _session;

  GuardianSessionState get current => _session.current;

  Stream<GuardianSessionState> call() => _session.watch();

  /// O servidor recusou a sessao atual. Quem cuida da sessao a encerra localmente.
  Stream<void> rejections() => _session.rejections;
}

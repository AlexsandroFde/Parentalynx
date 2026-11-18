import '../entities/guardian_session.dart';
import '../repositories/i_session_repository.dart';

/// Encerra a sessao local sem falar com o servidor: quando o servidor ja recusou a sessao ou
/// quando a conta acabou de ser excluida.
class EndSession {
  const EndSession(this._session);

  final ISessionRepository _session;

  Future<void> call(SessionEndReason reason) async {
    if (_session.current is SessionSignedOut) {
      return;
    }
    await _session.close(reason);
  }
}

import '../entities/guardian_session.dart';
import '../repositories/i_session_repository.dart';

/// A pessoa confirmou que guardou a chave de recuperacao: o painel pode ser usado.
class AcknowledgeRecoveryKey {
  const AcknowledgeRecoveryKey(this._session);

  final ISessionRepository _session;

  void call() {
    final GuardianSessionState current = _session.current;
    if (current is SessionOpen && current.pendingRecoveryKey != null) {
      _session.clearPendingRecoveryKey();
    }
  }
}

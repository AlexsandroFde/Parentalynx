import '../entities/guardian_session.dart';
import '../repositories/i_auth_repository.dart';
import '../repositories/i_session_repository.dart';

/// Encerra a sessao no servidor (se houver conexao) e neste aparelho.
class SignOut {
  const SignOut({required this._auth, required this._session});

  final IAuthRepository _auth;
  final ISessionRepository _session;

  Future<void> call() async {
    // Sem rede a sessao local e encerrada do mesmo jeito; o servidor a expira depois.
    await _auth.logout();
    await _session.close(SessionEndReason.signedOut);
  }
}

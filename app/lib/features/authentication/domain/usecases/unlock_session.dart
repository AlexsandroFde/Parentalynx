import '../../../../core/result/result.dart';
import '../entities/guardian_session.dart';
import '../repositories/i_auth_repository.dart';
import '../repositories/i_session_repository.dart';

/// Desbloqueia o painel. A verificacao da senha e a propria elevacao da sessao no servidor,
/// seguida da leitura da conta atualizada.
class UnlockSession {
  const UnlockSession({required this._auth, required this._session});

  final IAuthRepository _auth;
  final ISessionRepository _session;

  Future<Result<GuardianProfile>> call(String password) async {
    final Result<GuardianProfile> result = await (await _auth.elevate(password))
        .then<GuardianProfile>((int _) => _auth.fetchProfile());
    if (result case Ok<GuardianProfile>(:final GuardianProfile value)) {
      // A sessao pode ter terminado enquanto a senha era conferida (sessao recusada).
      if (_session.current is SessionLocked) {
        _session.unlock(value);
      }
    }
    return result;
  }
}

import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../repositories/i_auth_repository.dart';
import '../services/credentials_policy.dart';

/// Confirma a senha administrativa e libera as operacoes administrativas por alguns minutos
/// (protocolo, secao 2.2). Devolve o instante ate o qual a sessao fica elevada.
class ElevateSession {
  const ElevateSession(this._auth);

  final IAuthRepository _auth;

  Future<Result<int>> call(String password) async {
    final String? error = CredentialsPolicy.enteredPasswordError(password);
    if (error != null) {
      return Err<int>(ValidationFailure(error));
    }
    return _auth.elevate(password);
  }
}

import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/admin_auth.dart';
import '../services/i_guardian_authorization_service.dart';

/// Autentica o responsavel neste aparelho com a senha administrativa, conferida no servidor.
class VerifyGuardianPassword {
  const VerifyGuardianPassword(this._authorization);

  final IGuardianAuthorizationService _authorization;

  Future<Result<AdminAuth>> call(String password) async {
    if (password.isEmpty) {
      return const Err<AdminAuth>(ValidationFailure('Digite a senha administrativa.'));
    }
    return _authorization.verifyPassword(password);
  }
}

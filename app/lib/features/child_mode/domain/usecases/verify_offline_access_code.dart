import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/admin_auth.dart';
import '../services/i_guardian_authorization_service.dart';
import '../services/offline_access_code_rules.dart';

/// Autentica o responsavel com o codigo de acesso offline, conferido no proprio aparelho.
/// Funciona sem internet.
class VerifyOfflineAccessCode {
  const VerifyOfflineAccessCode(this._authorization);

  final IGuardianAuthorizationService _authorization;

  Future<Result<AdminAuth>> call(String code) async {
    final String digits = normalizeOfflineCode(code);
    if (digits.length != offlineCodeLength) {
      return const Err<AdminAuth>(ValidationFailure('O código tem 8 números.'));
    }
    return _authorization.verifyOfflineCode(digits);
  }
}

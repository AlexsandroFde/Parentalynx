import '../../../../core/platform/native_api.g.dart';
import '../../domain/entities/admin_auth.dart';

/// Converte o resultado da autenticacao do responsavel vindo do agente nativo.
abstract final class AdminAuthMapper {
  static AdminAuth from(AdminAuthResult result) {
    return AdminAuth(
      status: switch (result.outcome) {
        AdminAuthOutcome.ok => AdminAuthStatus.ok,
        AdminAuthOutcome.invalid => AdminAuthStatus.invalid,
        AdminAuthOutcome.locked => AdminAuthStatus.locked,
        AdminAuthOutcome.offline => AdminAuthStatus.offline,
        AdminAuthOutcome.error => AdminAuthStatus.error,
      },
      retryAfterSec: result.retryAfterSec,
      attemptsLeft: result.attemptsLeft,
      message: result.message,
    );
  }
}

import '../../../../core/result/result.dart';
import '../entities/admin_auth.dart';

/// Autenticacao do responsavel no aparelho da crianca.
///
/// Uma autenticacao aceita libera as operacoes administrativas no agente nativo por alguns
/// minutos. O agente recusa as operacoes protegidas depois disso (falha nativa com
/// `isAdminAuthRequired`).
abstract interface class IGuardianAuthorizationService {
  /// Confere a senha administrativa no servidor.
  Future<Result<AdminAuth>> verifyPassword(String password);

  /// Confere localmente o codigo de acesso offline (oito digitos).
  Future<Result<AdminAuth>> verifyOfflineCode(String code);
}

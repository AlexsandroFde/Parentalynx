import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/admin_auth.dart';
import '../../domain/services/i_guardian_authorization_service.dart';
import '../mappers/admin_auth_mapper.dart';

/// Autenticacao do responsavel pelo agente nativo ([ChildAgentApi]).
class NativeGuardianAuthorizationService implements IGuardianAuthorizationService {
  const NativeGuardianAuthorizationService(this._api);

  final ChildAgentApi _api;

  @override
  Future<Result<AdminAuth>> verifyPassword(String password) async {
    final Result<AdminAuthResult> result = await callNative<AdminAuthResult>(
      () => _api.verifyAdminPassword(password),
    );
    return result.map(AdminAuthMapper.from);
  }

  @override
  Future<Result<AdminAuth>> verifyOfflineCode(String code) async {
    final Result<AdminAuthResult> result = await callNative<AdminAuthResult>(
      () => _api.verifyOfflineCode(code),
    );
    return result.map(AdminAuthMapper.from);
  }
}

import '../../../../core/result/result.dart';
import '../entities/guardian_session.dart';
import '../repositories/i_auth_repository.dart';
import '../repositories/i_session_repository.dart';

/// Cria a conta do responsavel e abre o painel. A chave de recuperacao gerada fica pendente
/// ate a pessoa confirmar que guardou.
class RegisterGuardian {
  const RegisterGuardian({required this._auth, required this._session});

  /// Nome usado quando a pessoa apaga o nome sugerido para o aparelho.
  static const String fallbackDeviceName = 'Aparelho do responsável';

  final IAuthRepository _auth;
  final ISessionRepository _session;

  Future<Result<AuthenticatedSession>> call({
    required String email,
    required String displayName,
    required String password,
    required String deviceName,
  }) async {
    final String cleanDeviceName = deviceName.trim();
    final Result<AuthenticatedSession> result = await _auth.register(
      email: email.trim(),
      displayName: displayName.trim(),
      password: password,
      deviceName: cleanDeviceName.isEmpty ? fallbackDeviceName : cleanDeviceName,
    );
    if (result case Ok<AuthenticatedSession>(:final AuthenticatedSession value)) {
      await _session.open(value);
    }
    return result;
  }
}

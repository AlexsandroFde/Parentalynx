import '../../../../core/result/result.dart';
import '../entities/guardian_session.dart';
import '../repositories/i_auth_repository.dart';
import '../repositories/i_session_repository.dart';
import '../services/credentials_policy.dart';
import '../services/i_guardian_device_service.dart';

/// Troca a senha administrativa usando a chave de recuperacao e abre uma sessao nova.
///
/// O servidor gera uma chave nova (que fica pendente de confirmacao) e encerra as outras
/// sessoes da conta.
class RecoverAccess {
  const RecoverAccess({required this._auth, required this._session, required this._device});

  final IAuthRepository _auth;
  final ISessionRepository _session;
  final IGuardianDeviceService _device;

  Future<Result<AuthenticatedSession>> call({
    required String email,
    required String recoveryKey,
    required String newPassword,
  }) async {
    final Result<AuthenticatedSession> result = await _auth.recover(
      email: email.trim(),
      recoveryKey: CredentialsPolicy.normalizeRecoveryKey(recoveryKey),
      newPassword: newPassword,
      deviceName: await _device.deviceName(),
    );
    if (result case Ok<AuthenticatedSession>(:final AuthenticatedSession value)) {
      await _session.open(value);
    }
    return result;
  }
}

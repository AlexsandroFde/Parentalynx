import '../../../../core/result/result.dart';
import '../entities/guardian_session.dart';
import '../repositories/i_auth_repository.dart';
import '../repositories/i_session_repository.dart';
import '../services/i_guardian_device_service.dart';

/// Entra em uma conta que ja existe e abre o painel.
class SignIn {
  const SignIn({required this._auth, required this._session, required this._device});

  final IAuthRepository _auth;
  final ISessionRepository _session;
  final IGuardianDeviceService _device;

  Future<Result<AuthenticatedSession>> call({
    required String email,
    required String password,
  }) async {
    final Result<AuthenticatedSession> result = await _auth.login(
      email: email.trim(),
      password: password,
      deviceName: await _device.deviceName(),
    );
    if (result case Ok<AuthenticatedSession>(:final AuthenticatedSession value)) {
      await _session.open(value);
    }
    return result;
  }
}

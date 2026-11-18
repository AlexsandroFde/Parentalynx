import '../repositories/i_session_repository.dart';
import '../services/i_guardian_device_service.dart';

/// Valores para preencher os formularios de conta: o e-mail da ultima conta usada neste
/// aparelho e o nome do aparelho.
class GetSignInDefaults {
  const GetSignInDefaults({required this._session, required this._device});

  final ISessionRepository _session;
  final IGuardianDeviceService _device;

  Future<String?> storedEmail() => _session.storedEmail();

  Future<String> deviceName() => _device.deviceName();
}

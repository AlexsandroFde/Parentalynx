import '../../../../core/result/result.dart';
import '../services/i_device_management_service.dart';

/// Desativa o administrador do dispositivo. Exige a autenticacao do responsavel valida.
class DisableDeviceAdmin {
  const DisableDeviceAdmin(this._management);

  final IDeviceManagementService _management;

  Future<Result<void>> call() => _management.removeDeviceAdmin();
}

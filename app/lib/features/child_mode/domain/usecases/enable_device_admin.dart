import '../../../../core/result/result.dart';
import '../services/i_device_management_service.dart';

/// Pede ao sistema para ativar o administrador do dispositivo (reforco opcional contra a
/// desinstalacao).
class EnableDeviceAdmin {
  const EnableDeviceAdmin(this._management);

  final IDeviceManagementService _management;

  Future<Result<void>> call() => _management.requestDeviceAdmin();
}

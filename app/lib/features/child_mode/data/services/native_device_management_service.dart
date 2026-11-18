import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/services/i_device_management_service.dart';

/// Administrador do dispositivo e Device Owner pela ponte nativa ([DeviceApi]).
class NativeDeviceManagementService implements IDeviceManagementService {
  const NativeDeviceManagementService(this._api);

  final DeviceApi _api;

  @override
  Future<Result<void>> requestDeviceAdmin() => callNative<void>(_api.requestDeviceAdmin);

  @override
  Future<Result<void>> removeDeviceAdmin() => callNative<void>(_api.removeDeviceAdmin);

  @override
  Future<Result<bool>> releaseDeviceOwner() => callNative<bool>(_api.releaseDeviceOwner);
}

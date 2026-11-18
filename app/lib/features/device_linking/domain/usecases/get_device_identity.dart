import '../../../../core/result/result.dart';
import '../entities/device_identity.dart';
import '../services/i_device_identity_service.dart';

/// Informacoes deste aparelho (nome sugerido no vinculo, fabricante para as permissoes).
class GetDeviceIdentity {
  const GetDeviceIdentity(this._service);

  final IDeviceIdentityService _service;

  Future<Result<DeviceIdentity>> call() => _service.identity();
}

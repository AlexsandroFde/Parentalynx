import '../../../../core/result/result.dart';
import '../entities/device_identity.dart';

/// Informacoes deste aparelho lidas do sistema.
abstract interface class IDeviceIdentityService {
  Future<Result<DeviceIdentity>> identity();
}

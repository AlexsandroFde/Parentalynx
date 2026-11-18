import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/device_identity.dart';
import '../../domain/services/i_device_identity_service.dart';

/// Informacoes do aparelho lidas pela ponte nativa ([DeviceApi]).
class NativeDeviceIdentityService implements IDeviceIdentityService {
  const NativeDeviceIdentityService(this._api);

  final DeviceApi _api;

  @override
  Future<Result<DeviceIdentity>> identity() async {
    final Result<NativeDeviceInfo> info = await callNative<NativeDeviceInfo>(_api.getDeviceInfo);
    return info.map(
      (NativeDeviceInfo value) => DeviceIdentity(
        name: value.name,
        model: value.model,
        manufacturer: value.manufacturer,
        androidRelease: value.androidRelease,
        sdkInt: value.sdkInt,
        appVersion: value.appVersion,
        timezone: value.timezone,
        hardwareId: value.hardwareId,
      ),
    );
  }
}

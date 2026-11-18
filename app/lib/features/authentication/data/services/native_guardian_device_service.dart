import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/services/i_guardian_device_service.dart';

/// Nome deste aparelho lido do sistema pela ponte nativa ([DeviceApi]).
class NativeGuardianDeviceService implements IGuardianDeviceService {
  NativeGuardianDeviceService(this._api);

  static const String fallbackName = 'Aparelho do responsável';

  final DeviceApi _api;

  @override
  Future<String> deviceName() async {
    final Result<NativeDeviceInfo> info = await callNative<NativeDeviceInfo>(_api.getDeviceInfo);
    final String name = info.valueOrNull?.name.trim() ?? '';
    return name.isEmpty ? fallbackName : name;
  }
}

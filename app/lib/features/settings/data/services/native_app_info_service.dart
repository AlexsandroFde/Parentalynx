import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/services/i_app_info_service.dart';

/// Versao do app lida do sistema pela ponte nativa ([DeviceApi]).
class NativeAppInfoService implements IAppInfoService {
  const NativeAppInfoService(this._api);

  final DeviceApi _api;

  @override
  Future<String?> appVersion() async {
    final Result<NativeDeviceInfo> info = await callNative<NativeDeviceInfo>(_api.getDeviceInfo);
    return info.valueOrNull?.appVersion;
  }
}

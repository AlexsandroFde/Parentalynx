import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/services/i_application_blocking_service.dart';

/// Liberacao local pela ponte com o agente nativo ([ChildAgentApi]).
class NativeApplicationBlockingService implements IApplicationBlockingService {
  const NativeApplicationBlockingService(this._api);

  final ChildAgentApi _api;

  @override
  Future<Result<void>> grantLocalOverride(int minutes) {
    return callNative<void>(() => _api.grantLocalOverride(minutes));
  }

  @override
  Future<Result<void>> clearLocalOverride() => callNative<void>(_api.clearLocalOverride);
}

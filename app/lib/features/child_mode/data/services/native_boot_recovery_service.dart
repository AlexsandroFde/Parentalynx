import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/services/i_boot_recovery_service.dart';

/// Religa o servico do agente pela ponte nativa ([ChildAgentApi.ensureRunning]).
class NativeBootRecoveryService implements IBootRecoveryService {
  const NativeBootRecoveryService(this._api);

  final ChildAgentApi _api;

  @override
  Future<Result<void>> ensureRunning() => callNative<void>(_api.ensureRunning);
}

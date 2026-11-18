import '../../../../core/platform/native_api.g.dart' as native;
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/agent_status.dart';
import '../../domain/services/i_device_agent_service.dart';
import '../mappers/agent_status_mapper.dart';

/// Retrato do agente pela ponte nativa ([native.ChildAgentApi.getStatus]).
class NativeDeviceAgentService implements IDeviceAgentService {
  const NativeDeviceAgentService(this._api);

  final native.ChildAgentApi _api;

  @override
  Future<Result<AgentStatus>> status() async {
    final Result<native.AgentStatus> status = await callNative<native.AgentStatus>(_api.getStatus);
    return status.map(AgentStatusMapper.status);
  }
}

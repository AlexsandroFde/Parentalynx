import '../../../../core/result/result.dart';
import '../entities/agent_status.dart';
import '../services/i_device_agent_service.dart';

/// Retrato atual do agente de controle parental deste aparelho.
class GetAgentStatus {
  const GetAgentStatus(this._agent);

  final IDeviceAgentService _agent;

  Future<Result<AgentStatus>> call() => _agent.status();
}

import '../../../../core/result/result.dart';
import '../entities/agent_status.dart';

/// Consulta ao agente nativo de controle parental deste aparelho.
///
/// O agente aplica as regras com a interface fechada; a interface so pergunta como ele esta.
abstract interface class IDeviceAgentService {
  /// Retrato atual do agente.
  Future<Result<AgentStatus>> status();
}

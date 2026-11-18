import '../../../../core/result/result.dart';
import '../services/i_boot_recovery_service.dart';

/// Religa o servico do agente quando o app abre ou volta ao primeiro plano.
///
/// A falha nao impede o uso da tela: o agente tem outros caminhos para voltar (servico de
/// acessibilidade, reinicio do aparelho, tarefa periodica).
class EnsureAgentRunning {
  const EnsureAgentRunning(this._recovery);

  final IBootRecoveryService _recovery;

  Future<Result<void>> call() => _recovery.ensureRunning();
}

import '../../../../core/result/result.dart';

/// Recuperacao do servico do agente nativo.
///
/// O agente volta sozinho depois de reiniciar o aparelho, pelo servico de acessibilidade e
/// por uma tarefa periodica. Abrir o app e mais um caminho para religar o servico.
abstract interface class IBootRecoveryService {
  /// Garante que o servico do agente esta rodando.
  Future<Result<void>> ensureRunning();
}

import '../../../../core/result/result.dart';

/// Liberacao local do bloqueio neste aparelho, concedida pelo responsavel na area do
/// responsavel (modo crianca).
///
/// Quem bloqueia e libera de fato e o agente nativo; ele so aceita a liberacao com a
/// autenticacao do responsavel valida e a registra para o responsavel ver depois.
abstract interface class IApplicationBlockingService {
  /// Libera o uso por alguns minutos, mesmo com o tempo esgotado ou em horario de pausa.
  /// Falha com `NativeFailure` (`adminAuthRequired`) quando a autenticacao venceu.
  Future<Result<void>> grantLocalOverride(int minutes);

  /// Encerra a liberacao local antes do tempo. Nao exige autenticacao.
  Future<Result<void>> clearLocalOverride();
}

import '../../../../core/result/result.dart';
import '../entities/policy.dart';
import '../entities/versioned_policy.dart';

/// Comandos temporarios do responsavel (protocolo, secao 4). Cada comando grava em
/// `overrides`, gera uma versao nova da politica e devolve a politica resultante.
///
/// Todos sao operacoes administrativas (E).
abstract interface class IPolicyCommandRepository {
  /// Concede minutos extras para o dia corrente.
  Future<Result<VersionedPolicy>> grantExtraTime(String deviceId, {required int minutes});

  /// Bloqueia o aparelho agora. [until] nulo significa ate desbloquear manualmente.
  Future<Result<VersionedPolicy>> lock(String deviceId, {int? until});

  /// Encerra o bloqueio manual.
  Future<Result<VersionedPolicy>> unlock(String deviceId);

  /// Suspende regras por alguns minutos.
  Future<Result<VersionedPolicy>> suspend(
    String deviceId, {
    required int minutes,
    required List<SuspensionScope> scopes,
  });

  /// Encerra a suspensao de regras.
  Future<Result<VersionedPolicy>> clearSuspension(String deviceId);
}

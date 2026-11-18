import '../../../../core/result/result.dart';
import '../entities/policy.dart';
import '../entities/versioned_policy.dart';

/// Politica dos aparelhos no servidor (protocolo, secao 4.2).
abstract interface class IDevicePolicyRepository {
  /// Politica atual de um aparelho, com a versao do servidor.
  Future<Result<VersionedPolicy>> fetch(String deviceId);

  /// (E) Grava as regras editaveis (os comandos temporarios nao vao). Falha com `ApiFailure`
  /// de codigo `version_conflict` quando outra sessao alterou a politica depois de
  /// [baseVersion].
  Future<Result<VersionedPolicy>> replace(
    String deviceId, {
    required int baseVersion,
    required Policy policy,
  });
}

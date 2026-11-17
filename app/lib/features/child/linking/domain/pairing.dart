import '../../../../core/json/json_reader.dart';
import '../../agent/domain/child_models.dart';

/// Pedido de vinculo aceito pelo servidor e ainda aguardando a aprovacao do responsavel
/// (protocolo, secao 3).
class PairingClaim {
  const PairingClaim({
    required this.linkId,
    required this.pollToken,
    required this.confirmCode,
    required this.guardianName,
    required this.expiresAt,
  });

  factory PairingClaim.fromJson(JsonMap json) {
    return PairingClaim(
      linkId: json.str('linkId'),
      pollToken: json.str('pollToken'),
      confirmCode: json.str('confirmCode'),
      guardianName: json.strOrNull('guardianName') ?? '',
      expiresAt: json.intOr('expiresAt', fallback: 0),
    );
  }

  final String linkId;

  /// Token que so serve para consultar o andamento deste pedido.
  final String pollToken;

  /// Numero mostrado nos dois aparelhos para o responsavel conferir.
  final String confirmCode;
  final String guardianName;
  final int expiresAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'linkId': linkId,
      'pollToken': pollToken,
      'confirmCode': confirmCode,
      'guardianName': guardianName,
      'expiresAt': expiresAt,
    };
  }
}

/// Andamento de um pedido de vinculo.
sealed class PairingStatus {
  const PairingStatus();
}

final class PairingPending extends PairingStatus {
  const PairingPending();
}

final class PairingRejected extends PairingStatus {
  const PairingRejected();
}

final class PairingExpired extends PairingStatus {
  const PairingExpired();
}

/// Vinculo aprovado. As credenciais sao entregues uma unica vez pelo servidor.
final class PairingApproved extends PairingStatus {
  const PairingApproved({
    required this.deviceId,
    required this.deviceToken,
    required this.offlineSecret,
    required this.childName,
    required this.guardianName,
    required this.policyVersion,
    required this.policyJson,
  });

  final String deviceId;
  final String deviceToken;
  final String offlineSecret;
  final String childName;
  final String guardianName;
  final int policyVersion;

  /// Politica inicial, em texto JSON, no formato do protocolo.
  final String policyJson;
}

/// Acesso as rotas de vinculacao do servidor.
abstract interface class PairingRepository {
  /// Usa o codigo informado pelo responsavel para pedir o vinculo deste aparelho.
  Future<PairingClaim> claim({required String code, required DeviceIdentity device});

  /// Consulta o andamento do pedido.
  Future<PairingStatus> status(String pollToken);
}

/// Guarda o pedido em andamento, para continuar esperando se o app for fechado.
abstract interface class PendingClaimStore {
  Future<PairingClaim?> read();

  Future<void> write(PairingClaim claim);

  Future<void> clear();
}

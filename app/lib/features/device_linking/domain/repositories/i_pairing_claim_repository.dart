import '../../../../core/result/result.dart';
import '../entities/device_identity.dart';
import '../entities/pairing_claim.dart';
import '../entities/pairing_status.dart';

/// Pedido de vinculo deste aparelho no servidor (protocolo, secao 3.2).
abstract interface class IPairingClaimRepository {
  /// Usa o codigo informado pelo responsavel para pedir o vinculo deste aparelho.
  Future<Result<PairingClaim>> claim({required String code, required DeviceIdentity device});

  /// Consulta o andamento do pedido. Token recusado ou pedido desconhecido valem como pedido
  /// vencido.
  Future<Result<PairingStatus>> status(String pollToken);
}

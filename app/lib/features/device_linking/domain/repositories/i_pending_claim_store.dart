import '../../../../core/result/result.dart';
import '../entities/pairing_claim.dart';

/// Guarda o pedido em andamento, para continuar esperando se o app for fechado.
abstract interface class IPendingClaimStore {
  /// Pedido guardado, ou nulo quando nao ha (ou quando o que estava guardado nao pode ser
  /// lido).
  Future<Result<PairingClaim?>> read();

  Future<Result<void>> write(PairingClaim claim);

  Future<Result<void>> clear();
}

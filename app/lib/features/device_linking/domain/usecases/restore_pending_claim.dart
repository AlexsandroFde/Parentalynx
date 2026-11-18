import '../entities/pairing_claim.dart';
import '../repositories/i_pending_claim_store.dart';

/// Retoma a espera de um pedido de vinculo feito antes de o app ser fechado.
class RestorePendingClaim {
  const RestorePendingClaim(this._store);

  final IPendingClaimStore _store;

  /// Pedido guardado, ou nulo quando nao ha (uma falha de leitura vale como "sem pedido").
  Future<PairingClaim?> call() async => (await _store.read()).valueOrNull;
}

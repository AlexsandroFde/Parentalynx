import '../repositories/i_pending_claim_store.dart';

/// Esquece o pedido de vinculo em andamento (cancelado, recusado ou vencido).
class DiscardPendingClaim {
  const DiscardPendingClaim(this._store);

  final IPendingClaimStore _store;

  Future<void> call() async {
    // Sem o pedido guardado a espera simplesmente nao e retomada: nao ha o que tratar.
    await _store.clear();
  }
}

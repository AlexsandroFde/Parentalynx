import '../../../../core/result/result.dart';
import '../entities/pairing_claim.dart';
import '../entities/pairing_status.dart';
import '../repositories/i_pairing_claim_repository.dart';

/// Consulta se o responsavel ja respondeu ao pedido de vinculo.
class CheckPairingStatus {
  const CheckPairingStatus(this._claims);

  final IPairingClaimRepository _claims;

  Future<Result<PairingStatus>> call(PairingClaim claim) => _claims.status(claim.pollToken);
}

import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/security/pairing_code.dart';
import '../entities/device_identity.dart';
import '../entities/pairing_claim.dart';
import '../repositories/i_pairing_claim_repository.dart';
import '../repositories/i_pending_claim_store.dart';
import '../services/i_device_identity_service.dart';

/// Pede o vinculo deste aparelho com o codigo informado pelo responsavel.
///
/// O codigo precisa estar completo e o aparelho precisa de um nome. O pedido aceito fica
/// guardado para a espera continuar mesmo se o app for fechado.
class SubmitPairingCode {
  const SubmitPairingCode({required this._claims, required this._store, required this._identity});

  final IPairingClaimRepository _claims;
  final IPendingClaimStore _store;
  final IDeviceIdentityService _identity;

  Future<Result<PairingClaim>> call({required String code, required String deviceName}) async {
    if (!PairingCode.isComplete(code)) {
      return const Err<PairingClaim>(
        ValidationFailure('Digite o código completo. Ele tem 8 letras e números.'),
      );
    }
    final String name = deviceName.trim();
    if (name.isEmpty) {
      return const Err<PairingClaim>(ValidationFailure('Escolha um nome para este aparelho.'));
    }
    final Result<PairingClaim> claimed = await (await _identity.identity()).then<PairingClaim>(
      (DeviceIdentity identity) => _claims.claim(code: code, device: identity.withName(name)),
    );
    return claimed.then<PairingClaim>((PairingClaim claim) async {
      return (await _store.write(claim)).map((void _) => claim);
    });
  }
}

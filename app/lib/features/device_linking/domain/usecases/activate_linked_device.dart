import '../../../../core/result/result.dart';
import '../entities/device_activation.dart';
import '../entities/link_state.dart';
import '../entities/pairing_claim.dart';
import '../entities/pairing_status.dart';
import '../repositories/i_link_state_repository.dart';
import '../repositories/i_pending_claim_store.dart';
import '../services/i_device_activation_service.dart';

/// Liga o controle parental neste aparelho depois que o responsavel aprovou o vinculo.
///
/// O pedido guardado e descartado de qualquer jeito: as credenciais so sao entregues uma vez,
/// entao uma falha aqui exige um codigo novo. Ao ligar, o vinculo passa para a configuracao
/// inicial (transparencia e permissoes).
class ActivateLinkedDevice {
  const ActivateLinkedDevice({
    required this._activation,
    required this._store,
    required this._linkState,
  });

  final IDeviceActivationService _activation;
  final IPendingClaimStore _store;
  final ILinkStateRepository _linkState;

  Future<Result<void>> call(PairingClaim claim, PairingApproved approved) async {
    final Result<void> result = await _activation.activate(
      DeviceActivation(
        deviceId: approved.deviceId,
        deviceToken: approved.deviceToken,
        offlineSecret: approved.offlineSecret,
        childName: approved.childName,
        guardianName: approved.guardianName.isNotEmpty ? approved.guardianName : claim.guardianName,
        policyVersion: approved.policyVersion,
        initialPolicy: approved.initialPolicy,
      ),
    );
    await _store.clear();
    if (result.isOk) {
      _linkState.update(const LinkState(LinkPhase.onboarding));
    }
    return result;
  }
}

import '../../../../core/result/result.dart';
import '../../../child_device/domain/repositories/i_child_device_repository.dart';
import '../entities/link_code.dart';
import '../entities/link_request.dart';
import '../entities/linking_overview.dart';
import '../repositories/i_guardian_linking_repository.dart';
import '../services/link_request_rules.dart';

/// Consulta o servidor: pedidos aguardando aprovacao e situacao do codigo mostrado.
///
/// O codigo mostrado deixa a tela quando o servidor nao o considera mais ativo (foi usado,
/// cancelado ou venceu). Se um codigo foi gerado ou cancelado durante a consulta, a resposta
/// nao decide sobre ele. Quando os pedidos mudam, a lista de aparelhos e recarregada, para o
/// painel mostrar os pedidos pendentes.
class CheckLinkRequests {
  const CheckLinkRequests({required this._repository, required this._devices});

  final IGuardianLinkingRepository _repository;
  final IChildDeviceRepository _devices;

  /// [previous] sao os pedidos que a tela mostra agora.
  Future<Result<LinkingSnapshot>> call({List<LinkRequest> previous = const <LinkRequest>[]}) async {
    final LinkCode? shownBefore = _repository.shownCode;
    final Result<LinkingOverview> result = await _repository.overview();
    final LinkingOverview? overview = result.valueOrNull;
    if (overview == null) {
      return Err<LinkingSnapshot>(result.failureOrNull!);
    }
    final LinkCode? shown = _repository.shownCode;
    final LinkingSnapshot snapshot;
    if (shown?.id != shownBefore?.id) {
      snapshot = LinkingSnapshot(
        requests: overview.requests,
        codeChangedMeanwhile: true,
        shownCode: shown,
      );
    } else {
      final ActiveLinkCode? active = overview.activeCode;
      final bool shownStillActive = shown != null && active != null && active.id == shown.id;
      if (shown != null && !shownStillActive) {
        _repository.forgetCode(shown.id);
      }
      snapshot = LinkingSnapshot(
        requests: overview.requests,
        codeChangedMeanwhile: false,
        shownCode: shownStillActive ? shown : null,
        otherCodeExpiresAt: active != null && !shownStillActive ? active.expiresAt : null,
      );
    }
    if (!LinkRequestRules.sameRequests(previous, overview.requests)) {
      await _devices.refresh();
    }
    return Ok<LinkingSnapshot>(snapshot);
  }
}

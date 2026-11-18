import '../entities/link_state.dart';
import '../repositories/i_link_state_repository.dart';

/// O agente respondeu que nao esta mais ativo: o responsavel removeu o vinculo. O aparelho
/// volta para a tela do codigo com a explicacao.
class ReportAgentInactive {
  const ReportAgentInactive(this._linkState);

  final ILinkStateRepository _linkState;

  void call() {
    if (_linkState.current.phase.isLinked) {
      _linkState.update(
        const LinkState(LinkPhase.unlinked, unlinkReason: UnlinkReason.revokedByGuardian),
      );
    }
  }
}

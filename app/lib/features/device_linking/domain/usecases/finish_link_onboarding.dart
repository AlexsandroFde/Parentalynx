import '../entities/link_state.dart';
import '../repositories/i_link_state_repository.dart';

/// A configuracao inicial (transparencia e permissoes) terminou: o aparelho passa a mostrar a
/// tela inicial da crianca.
class FinishLinkOnboarding {
  const FinishLinkOnboarding(this._linkState);

  final ILinkStateRepository _linkState;

  void call() {
    if (_linkState.current.phase == LinkPhase.onboarding) {
      _linkState.update(const LinkState(LinkPhase.ready));
    }
  }
}

/// Acao pedida por quem abriu o app (notificacao ou tela de bloqueio nativa).
enum LaunchAction {
  /// Abrir a central de alertas (modo responsavel).
  alerts('alerts'),

  /// Abrir a area do responsavel no aparelho da crianca.
  guardianArea('guardian_area'),

  /// Abrir a tela inicial da crianca.
  childHome('child_home'),

  /// Abrir as permissoes do controle no aparelho da crianca.
  permissions('permissions');

  const LaunchAction(this.code);

  final String code;

  static LaunchAction? parse(String code) {
    for (final LaunchAction action in values) {
      if (action.code == code) {
        return action;
      }
    }
    return null;
  }
}

/// Fonte das acoes de abertura.
///
/// A acao fica pendente ate alguem trata-la e chamar [consume]: assim uma acao que chega
/// enquanto a tela certa ainda nao existe (painel bloqueado, por exemplo) nao se perde.
abstract interface class LaunchActionSource {
  /// Acao pendente atual seguida das mudancas. Nulo quando nao ha acao pendente.
  Stream<LaunchAction?> watchPending();

  /// Marca a acao pendente como tratada.
  void consume();
}

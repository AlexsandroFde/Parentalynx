part of 'child_shell_bloc.dart';

/// Tela do modo crianca pedida por uma acao de abertura.
enum ChildLaunchDestination { home, guardianArea, permissions }

final class ChildShellState extends Equatable {
  const ChildShellState({required this.phase, this.pendingAction});

  final LinkPhase phase;

  /// Acao pedida por quem abriu o app, ainda nao tratada.
  final LaunchAction? pendingAction;

  /// Tela a abrir agora. Nulo enquanto a acao espera o aparelho ficar pronto, ou quando a
  /// acao nao leva a nenhuma tela deste modo.
  ChildLaunchDestination? get destination {
    if (phase != LinkPhase.ready) {
      return null;
    }
    return switch (pendingAction) {
      LaunchAction.guardianArea => ChildLaunchDestination.guardianArea,
      LaunchAction.permissions => ChildLaunchDestination.permissions,
      LaunchAction.childHome => ChildLaunchDestination.home,
      // Acoes do outro modo (como `alerts`) nao se aplicam aqui.
      LaunchAction.alerts || null => null,
    };
  }

  /// Verdadeiro quando a acao pendente nao vai ser atendida e deve ser descartada: o aparelho
  /// nao esta vinculado, ou a acao nao leva a nenhuma tela deste modo.
  bool get discardsPendingAction {
    if (pendingAction == null) {
      return false;
    }
    return switch (phase) {
      // Ainda carregando ou configurando: a acao espera a tela inicial ficar disponivel.
      LinkPhase.unknown || LinkPhase.onboarding => false,
      LinkPhase.failed || LinkPhase.unlinked => true,
      LinkPhase.ready => destination == null,
    };
  }

  @override
  List<Object?> get props => <Object?>[phase, pendingAction];
}

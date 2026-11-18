part of 'child_shell_bloc.dart';

sealed class ChildShellEvent extends Equatable {
  const ChildShellEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A casca apareceu: acompanha as acoes de abertura e a situacao do vinculo.
final class ChildShellStarted extends ChildShellEvent {
  const ChildShellStarted();
}

/// A casca ja levou a pessoa para a tela que a acao de abertura pedia.
final class ChildShellLaunchActionHandled extends ChildShellEvent {
  const ChildShellLaunchActionHandled();
}

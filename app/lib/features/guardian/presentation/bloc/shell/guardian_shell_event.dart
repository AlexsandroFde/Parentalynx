part of 'guardian_shell_bloc.dart';

sealed class GuardianShellEvent extends Equatable {
  const GuardianShellEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A casca do painel apareceu: acompanha as acoes de abertura.
final class GuardianShellStarted extends GuardianShellEvent {
  const GuardianShellStarted();
}

/// A casca ja levou a pessoa para onde a acao de abertura pedia.
final class GuardianShellLaunchActionHandled extends GuardianShellEvent {
  const GuardianShellLaunchActionHandled();
}

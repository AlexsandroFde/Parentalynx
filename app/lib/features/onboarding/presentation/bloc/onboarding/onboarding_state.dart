part of 'onboarding_bloc.dart';

final class OnboardingState extends Equatable {
  const OnboardingState({this.choosing, this.awaitingServerFor, this.action = const ActionIdle()});

  /// Papel sendo gravado agora. Enquanto houver um, as opcoes ficam inativas.
  final UserRole? choosing;

  /// A pessoa escolheu este papel, mas falta configurar o servidor: a tela abre a folha do
  /// servidor e avisa quando ela fechar.
  final UserRole? awaitingServerFor;

  /// Andamento da gravacao do papel.
  final ActionStatus action;

  bool get isBusy => choosing != null;

  @override
  List<Object?> get props => <Object?>[choosing, awaitingServerFor, action];
}

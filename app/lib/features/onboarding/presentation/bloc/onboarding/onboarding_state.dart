part of 'onboarding_bloc.dart';

final class OnboardingState extends Equatable {
  const OnboardingState({this.choosing, this.action = const ActionIdle()});

  /// Papel sendo gravado agora. Enquanto houver um, as opcoes ficam inativas.
  final UserRole? choosing;

  /// Andamento da gravacao do papel.
  final ActionStatus action;

  bool get isBusy => choosing != null;

  @override
  List<Object?> get props => <Object?>[choosing, action];
}

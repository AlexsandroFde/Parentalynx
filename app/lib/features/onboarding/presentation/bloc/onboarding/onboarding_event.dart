part of 'onboarding_bloc.dart';

sealed class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A pessoa escolheu o papel deste aparelho.
final class OnboardingRoleChosen extends OnboardingEvent {
  const OnboardingRoleChosen(this.role);

  final UserRole role;

  @override
  List<Object?> get props => <Object?>[role];
}

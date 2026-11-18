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

/// A folha do servidor, aberta porque faltava o endereco, foi fechada. [saved] diz se um
/// endereco valido foi gravado.
final class OnboardingServerSheetClosed extends OnboardingEvent {
  const OnboardingServerSheetClosed({required this.saved});

  final bool saved;

  @override
  List<Object?> get props => <Object?>[saved];
}

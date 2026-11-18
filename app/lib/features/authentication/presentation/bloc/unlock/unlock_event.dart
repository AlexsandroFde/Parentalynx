part of 'unlock_bloc.dart';

sealed class UnlockEvent extends Equatable {
  const UnlockEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela de bloqueio abriu: descobre qual conta esta conectada.
final class UnlockStarted extends UnlockEvent {
  const UnlockStarted();
}

/// A pessoa voltou a digitar a senha: o erro some.
final class UnlockPasswordEdited extends UnlockEvent {
  const UnlockPasswordEdited();
}

/// A pessoa tocou em "Desbloquear".
final class UnlockSubmitted extends UnlockEvent {
  const UnlockSubmitted(this.password);

  final String password;

  @override
  List<Object?> get props => <Object?>[password];
}

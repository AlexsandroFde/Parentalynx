part of 'recover_access_bloc.dart';

sealed class RecoverAccessEvent extends Equatable {
  const RecoverAccessEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela abriu: busca o e-mail da ultima conta usada neste aparelho.
final class RecoverAccessStarted extends RecoverAccessEvent {
  const RecoverAccessStarted();
}

/// A pessoa voltou a digitar em um campo: o erro dele some.
final class RecoverAccessFieldEdited extends RecoverAccessEvent {
  const RecoverAccessFieldEdited(this.field);

  final CredentialField field;

  @override
  List<Object?> get props => <Object?>[field];
}

/// A pessoa tocou em "Recuperar acesso".
final class RecoverAccessSubmitted extends RecoverAccessEvent {
  const RecoverAccessSubmitted({
    required this.email,
    required this.recoveryKey,
    required this.password,
    required this.confirmation,
  });

  final String email;
  final String recoveryKey;
  final String password;
  final String confirmation;

  @override
  List<Object?> get props => <Object?>[email, recoveryKey, password, confirmation];
}

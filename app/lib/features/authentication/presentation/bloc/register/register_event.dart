part of 'register_bloc.dart';

sealed class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela abriu: busca o nome sugerido para este aparelho.
final class RegisterStarted extends RegisterEvent {
  const RegisterStarted();
}

/// A pessoa voltou a digitar em um campo: o erro dele some.
final class RegisterFieldEdited extends RegisterEvent {
  const RegisterFieldEdited(this.field);

  final CredentialField field;

  @override
  List<Object?> get props => <Object?>[field];
}

/// A pessoa tocou em "Criar conta".
final class RegisterSubmitted extends RegisterEvent {
  const RegisterSubmitted({
    required this.displayName,
    required this.email,
    required this.password,
    required this.confirmation,
    required this.deviceName,
  });

  final String displayName;
  final String email;
  final String password;
  final String confirmation;
  final String deviceName;

  @override
  List<Object?> get props => <Object?>[displayName, email, password, confirmation, deviceName];
}

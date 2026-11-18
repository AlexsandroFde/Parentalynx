part of 'change_password_bloc.dart';

sealed class ChangePasswordEvent extends Equatable {
  const ChangePasswordEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A pessoa voltou a digitar em um campo: o erro dele some.
final class ChangePasswordFieldEdited extends ChangePasswordEvent {
  const ChangePasswordFieldEdited(this.field);

  final PasswordChangeField field;

  @override
  List<Object?> get props => <Object?>[field];
}

/// A pessoa tocou em "Trocar senha".
final class ChangePasswordSubmitted extends ChangePasswordEvent {
  const ChangePasswordSubmitted({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmation,
  });

  final String currentPassword;
  final String newPassword;
  final String confirmation;

  @override
  List<Object?> get props => <Object?>[currentPassword, newPassword, confirmation];
}

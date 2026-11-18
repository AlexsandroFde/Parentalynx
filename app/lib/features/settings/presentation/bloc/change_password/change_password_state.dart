part of 'change_password_bloc.dart';

final class ChangePasswordState extends Equatable {
  const ChangePasswordState({
    this.status = FormStatus.editing,
    this.errors = PasswordChangeErrors.none,
    this.email,
    this.displayName,
  });

  final FormStatus status;
  final PasswordChangeErrors errors;

  /// E-mail e nome da conta: a senha nova nao pode se parecer com eles.
  final String? email;
  final String? displayName;

  ChangePasswordState copyWith({FormStatus? status, PasswordChangeErrors? errors}) {
    return ChangePasswordState(
      status: status ?? this.status,
      errors: errors ?? this.errors,
      email: email,
      displayName: displayName,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, errors, email, displayName];
}

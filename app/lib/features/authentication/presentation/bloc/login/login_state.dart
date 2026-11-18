part of 'login_bloc.dart';

final class LoginState extends Equatable {
  const LoginState({this.status = FormStatus.editing, this.errors = CredentialErrors.none});

  final FormStatus status;
  final CredentialErrors errors;

  @override
  List<Object?> get props => <Object?>[status, errors];
}

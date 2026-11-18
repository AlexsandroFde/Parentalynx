part of 'recover_access_bloc.dart';

final class RecoverAccessState extends Equatable {
  const RecoverAccessState({
    this.status = FormStatus.editing,
    this.errors = CredentialErrors.none,
    this.storedEmail,
  });

  final FormStatus status;
  final CredentialErrors errors;

  /// E-mail da ultima conta usada neste aparelho, para preencher o campo uma vez.
  final String? storedEmail;

  RecoverAccessState copyWith({FormStatus? status, CredentialErrors? errors, String? storedEmail}) {
    return RecoverAccessState(
      status: status ?? this.status,
      errors: errors ?? this.errors,
      storedEmail: storedEmail ?? this.storedEmail,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, errors, storedEmail];
}

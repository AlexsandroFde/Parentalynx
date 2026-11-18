part of 'register_bloc.dart';

final class RegisterState extends Equatable {
  const RegisterState({
    this.status = FormStatus.editing,
    this.errors = CredentialErrors.none,
    this.suggestedDeviceName,
  });

  final FormStatus status;
  final CredentialErrors errors;

  /// Nome deste aparelho informado pelo sistema, para preencher o campo uma vez.
  final String? suggestedDeviceName;

  RegisterState copyWith({
    FormStatus? status,
    CredentialErrors? errors,
    String? suggestedDeviceName,
  }) {
    return RegisterState(
      status: status ?? this.status,
      errors: errors ?? this.errors,
      suggestedDeviceName: suggestedDeviceName ?? this.suggestedDeviceName,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, errors, suggestedDeviceName];
}

part of 'unlock_bloc.dart';

final class UnlockState extends Equatable {
  const UnlockState({this.status = FormStatus.editing, this.error, this.email});

  final FormStatus status;

  /// Motivo da recusa da senha.
  final String? error;

  /// E-mail da conta conectada, para a pessoa saber de quem e a senha pedida.
  final String? email;

  UnlockState copyWith({
    FormStatus? status,
    String? error,
    bool clearError = false,
    String? email,
  }) {
    return UnlockState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      email: email ?? this.email,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, error, email];
}

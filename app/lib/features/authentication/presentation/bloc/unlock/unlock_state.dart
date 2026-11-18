part of 'unlock_bloc.dart';

final class UnlockState extends Equatable {
  const UnlockState({this.status = FormStatus.editing, this.error, this.email, this.displayName});

  final FormStatus status;

  /// Motivo da recusa da senha.
  final String? error;

  /// E-mail da conta conectada, para a pessoa saber de quem e a senha pedida.
  final String? email;

  /// Nome da conta, quando o bloqueio aconteceu com o app ja aberto.
  final String? displayName;

  UnlockState copyWith({
    FormStatus? status,
    String? error,
    bool clearError = false,
    String? email,
    String? displayName,
  }) {
    return UnlockState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, error, email, displayName];
}

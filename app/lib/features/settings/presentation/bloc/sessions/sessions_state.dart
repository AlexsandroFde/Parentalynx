part of 'sessions_bloc.dart';

/// Sessoes conectadas a conta.
sealed class SessionsState extends Equatable {
  const SessionsState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class SessionsLoading extends SessionsState {
  const SessionsLoading();
}

/// A lista nao carregou. A tela oferece tentar de novo.
final class SessionsError extends SessionsState {
  const SessionsError(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}

final class SessionsLoaded extends SessionsState {
  const SessionsLoaded({required this.sessions, this.action = const ActionIdle(), this.revokingId});

  final List<GuardianSessionInfo> sessions;

  /// Andamento do encerramento de uma sessao.
  final ActionStatus action;

  /// Sessao sendo encerrada agora, para a tela mostrar o andamento na linha certa.
  final String? revokingId;

  SessionsLoaded copyWith({
    List<GuardianSessionInfo>? sessions,
    ActionStatus? action,
    String? revokingId,
  }) {
    return SessionsLoaded(
      sessions: sessions ?? this.sessions,
      action: action ?? this.action,
      revokingId: revokingId,
    );
  }

  @override
  List<Object?> get props => <Object?>[sessions, action, revokingId];
}

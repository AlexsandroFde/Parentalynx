part of 'sessions_bloc.dart';

sealed class SessionsEvent extends Equatable {
  const SessionsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Carregar a lista: a tela abriu ou a pessoa pediu para tentar de novo.
final class SessionsLoadRequested extends SessionsEvent {
  const SessionsLoadRequested();
}

/// A pessoa confirmou o encerramento da sessao de outro aparelho.
final class SessionRevokeRequested extends SessionsEvent {
  const SessionRevokeRequested(this.sessionId);

  final String sessionId;

  @override
  List<Object?> get props => <Object?>[sessionId];
}

part of 'auth_bloc.dart';

/// Situacao da sessao vista pela interface.
sealed class AuthState extends Equatable {
  const AuthState();

  factory AuthState.fromSession(GuardianSessionState session) {
    return switch (session) {
      SessionSignedOut(:final SessionEndReason? reason) => AuthSignedOut(reason: reason),
      SessionLocked(:final GuardianAccount? account) => AuthLocked(account: account),
      SessionOpen(
        :final GuardianAccount account,
        :final GuardianSessionInfo session,
        :final String? pendingRecoveryKey,
      ) =>
        AuthReady(account: account, session: session, pendingRecoveryKey: pendingRecoveryKey),
    };
  }
}

/// Sem sessao: telas de criar conta e entrar.
final class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.reason});

  final SessionEndReason? reason;

  /// Explica por que a sessao anterior terminou, quando nao foi a pessoa que saiu.
  String? get notice {
    return switch (reason) {
      SessionEndReason.expired =>
        'Sua sessão terminou por tempo ou foi encerrada em outro aparelho. Entre de novo para '
            'continuar.',
      SessionEndReason.accountDeleted =>
        'A conta, os aparelhos vinculados, as regras e todo o histórico foram apagados.',
      SessionEndReason.signedOut || null => null,
    };
  }

  @override
  List<Object?> get props => <Object?>[reason];
}

/// Sessao gravada, painel bloqueado: pede a senha administrativa.
final class AuthLocked extends AuthState {
  const AuthLocked({this.account});

  /// Conta conhecida, quando o bloqueio aconteceu com o app ja aberto.
  final GuardianAccount? account;

  @override
  List<Object?> get props => <Object?>[account];
}

/// Painel aberto.
final class AuthReady extends AuthState {
  const AuthReady({required this.account, required this.session, this.pendingRecoveryKey});

  final GuardianAccount account;
  final GuardianSessionInfo session;

  /// Chave de recuperacao recem-gerada que ainda precisa ser mostrada e confirmada.
  final String? pendingRecoveryKey;

  @override
  List<Object?> get props => <Object?>[account, session, pendingRecoveryKey];
}

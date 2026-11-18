part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Passa a acompanhar a sessao e os avisos de sessao recusada. Disparado na criacao.
final class AuthSubscriptionRequested extends AuthEvent {
  const AuthSubscriptionRequested();
}

/// O app foi para o segundo plano.
final class AuthAppPaused extends AuthEvent {
  const AuthAppPaused();
}

/// O app voltou ao primeiro plano. Bloqueia o painel se ficou fora mais que o tempo escolhido.
final class AuthAppResumed extends AuthEvent {
  const AuthAppResumed();
}

/// O responsavel pediu para bloquear o painel agora.
final class AuthLockRequested extends AuthEvent {
  const AuthLockRequested();
}

/// O responsavel saiu da conta neste aparelho.
final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

/// A pessoa confirmou que guardou a chave de recuperacao.
final class AuthRecoveryKeyAcknowledged extends AuthEvent {
  const AuthRecoveryKeyAcknowledged();
}

/// Recarregar a conta do servidor (depois de voltar a uma tela de conta).
final class AuthAccountRefreshRequested extends AuthEvent {
  const AuthAccountRefreshRequested();
}

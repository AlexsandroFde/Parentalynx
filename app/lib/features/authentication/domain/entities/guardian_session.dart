import 'package:equatable/equatable.dart';

import 'guardian_account.dart';

/// Sessao do responsavel em um aparelho (protocolo, secao 2.1).
final class GuardianSessionInfo extends Equatable {
  const GuardianSessionInfo({
    required this.id,
    required this.deviceName,
    required this.createdAt,
    required this.lastSeenAt,
    required this.expiresAt,
    required this.elevatedUntil,
    required this.current,
  });

  final String id;
  final String deviceName;
  final int createdAt;
  final int lastSeenAt;
  final int expiresAt;

  /// Instante ate o qual as operacoes administrativas estao liberadas sem pedir a senha.
  final int elevatedUntil;

  /// Verdadeiro quando e a sessao deste aparelho.
  final bool current;

  @override
  List<Object?> get props => <Object?>[
    id,
    deviceName,
    createdAt,
    lastSeenAt,
    expiresAt,
    elevatedUntil,
    current,
  ];
}

/// Conta e sessao atuais (`GET /v1/guardian/me`).
final class GuardianProfile extends Equatable {
  const GuardianProfile({required this.account, required this.session});

  final GuardianAccount account;
  final GuardianSessionInfo session;

  @override
  List<Object?> get props => <Object?>[account, session];
}

/// Sessao recem-criada por registro, entrada ou recuperacao, com o seu token.
final class AuthenticatedSession extends Equatable {
  const AuthenticatedSession({
    required this.account,
    required this.session,
    required this.token,
    this.recoveryKey,
  });

  final GuardianAccount account;
  final GuardianSessionInfo session;

  /// Token `gs_` da sessao. So vem na criacao.
  final String token;

  /// Chave de recuperacao. Vem no registro e na recuperacao, e e mostrada uma unica vez.
  final String? recoveryKey;

  @override
  List<Object?> get props => <Object?>[account, session, token, recoveryKey];
}

/// Por que a sessao deste aparelho terminou.
enum SessionEndReason {
  /// A pessoa saiu da conta.
  signedOut,

  /// O servidor recusou a sessao (vencida ou encerrada em outro aparelho).
  expired,

  /// A conta foi excluida.
  accountDeleted,
}

/// Situacao da sessao do responsavel neste aparelho. E a fonte unica de verdade para o
/// roteador, o painel e os servicos que dependem de sessao (alertas em segundo plano).
sealed class GuardianSessionState extends Equatable {
  const GuardianSessionState();
}

/// Nao ha sessao. [reason] diz por que a sessao anterior terminou, quando houve uma.
final class SessionSignedOut extends GuardianSessionState {
  const SessionSignedOut({this.reason});

  final SessionEndReason? reason;

  @override
  List<Object?> get props => <Object?>[reason];
}

/// Ha sessao, mas o painel esta bloqueado e pede a senha administrativa.
final class SessionLocked extends GuardianSessionState {
  const SessionLocked({this.account});

  /// Conta conhecida, quando o bloqueio aconteceu com o app ja aberto.
  final GuardianAccount? account;

  @override
  List<Object?> get props => <Object?>[account];
}

/// Sessao aberta e painel desbloqueado.
final class SessionOpen extends GuardianSessionState {
  const SessionOpen({required this.account, required this.session, this.pendingRecoveryKey});

  final GuardianAccount account;
  final GuardianSessionInfo session;

  /// Chave de recuperacao recem-gerada que ainda precisa ser mostrada e confirmada.
  final String? pendingRecoveryKey;

  SessionOpen withAccount(GuardianAccount value) {
    return SessionOpen(account: value, session: session, pendingRecoveryKey: pendingRecoveryKey);
  }

  @override
  List<Object?> get props => <Object?>[account, session, pendingRecoveryKey];
}

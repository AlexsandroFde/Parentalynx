part of 'account_bloc.dart';

/// Comando da tela de conta, para a tela escolher o texto do aviso de falha.
enum AccountCommand { rename, recoveryKey }

final class AccountState extends Equatable {
  const AccountState({
    this.account,
    this.command,
    this.action = const ActionIdle(),
    this.recoveryKey,
  });

  /// Conta atual, ou nulo quando o painel nao esta aberto.
  final GuardianAccount? account;

  /// Ultimo comando disparado.
  final AccountCommand? command;
  final ActionStatus action;

  /// Chave de recuperacao recem-gerada, que a tela mostra uma unica vez.
  final String? recoveryKey;

  AccountState copyWith({AccountCommand? command, ActionStatus? action, String? recoveryKey}) {
    return AccountState(
      account: account,
      command: command ?? this.command,
      action: action ?? this.action,
      recoveryKey: recoveryKey ?? this.recoveryKey,
    );
  }

  AccountState withAccount(GuardianAccount? value) {
    return AccountState(account: value, command: command, action: action, recoveryKey: recoveryKey);
  }

  AccountState withoutRecoveryKey() {
    return AccountState(account: account, command: command, action: action);
  }

  @override
  List<Object?> get props => <Object?>[account, command, action, recoveryKey];
}

part of 'account_settings_bloc.dart';

final class AccountSettingsState extends Equatable {
  const AccountSettingsState({this.account, this.action = const ActionIdle()});

  /// Conta atual, ou nulo quando o painel nao esta aberto.
  final GuardianAccount? account;

  /// Andamento da gravacao de um ajuste.
  final ActionStatus action;

  GuardianSettings? get settings => account?.settings;

  AccountSettingsState withAccount(GuardianAccount? value) {
    return AccountSettingsState(account: value, action: action);
  }

  AccountSettingsState withAction(ActionStatus value) {
    return AccountSettingsState(account: account, action: value);
  }

  @override
  List<Object?> get props => <Object?>[account, action];
}

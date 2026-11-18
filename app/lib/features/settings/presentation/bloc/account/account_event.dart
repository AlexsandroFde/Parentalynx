part of 'account_bloc.dart';

sealed class AccountEvent extends Equatable {
  const AccountEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela abriu: acompanha a conta em memoria.
final class AccountStarted extends AccountEvent {
  const AccountStarted();
}

/// A pessoa confirmou um nome novo no dialogo.
final class AccountNameSubmitted extends AccountEvent {
  const AccountNameSubmitted(this.name);

  final String name;

  @override
  List<Object?> get props => <Object?>[name];
}

/// A pessoa confirmou a senha para gerar uma nova chave de recuperacao.
final class AccountRecoveryKeyRequested extends AccountEvent {
  const AccountRecoveryKeyRequested(this.password);

  final String password;

  @override
  List<Object?> get props => <Object?>[password];
}

/// A tela abriu a chave nova. Ela nao fica guardada no estado.
final class AccountRecoveryKeyShown extends AccountEvent {
  const AccountRecoveryKeyShown();
}

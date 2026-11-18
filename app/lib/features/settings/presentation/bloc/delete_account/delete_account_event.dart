part of 'delete_account_bloc.dart';

sealed class DeleteAccountEvent extends Equatable {
  const DeleteAccountEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A pessoa voltou a digitar a senha: o erro some.
final class DeleteAccountPasswordEdited extends DeleteAccountEvent {
  const DeleteAccountPasswordEdited();
}

/// A pessoa tocou em "Excluir conta e todos os dados".
final class DeleteAccountSubmitted extends DeleteAccountEvent {
  const DeleteAccountSubmitted({required this.password, required this.word});

  final String password;

  /// Palavra de confirmacao digitada.
  final String word;

  @override
  List<Object?> get props => <Object?>[password, word];
}

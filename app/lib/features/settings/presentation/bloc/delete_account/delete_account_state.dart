part of 'delete_account_bloc.dart';

final class DeleteAccountState extends Equatable {
  const DeleteAccountState({
    this.status = FormStatus.editing,
    this.error,
    this.formError,
    this.email,
  });

  final FormStatus status;

  /// Recusa da senha, mostrada no campo da senha.
  final String? error;

  /// Falha sem relacao com a senha (sem conexao, erro do servidor). Nada foi apagado.
  final String? formError;

  /// Conta que sera excluida, para a pessoa conferir antes de confirmar.
  final String? email;

  @override
  List<Object?> get props => <Object?>[status, error, formError, email];
}

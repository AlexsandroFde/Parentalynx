part of 'delete_account_bloc.dart';

final class DeleteAccountState extends Equatable {
  const DeleteAccountState({this.status = FormStatus.editing, this.error});

  final FormStatus status;

  /// Recusa do servidor, mostrada no campo da senha.
  final String? error;

  @override
  List<Object?> get props => <Object?>[status, error];
}

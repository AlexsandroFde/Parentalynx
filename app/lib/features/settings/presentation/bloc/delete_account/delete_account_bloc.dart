import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/bloc/form_status.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../domain/services/account_rules.dart';
import '../../../domain/usecases/delete_account.dart';
import '../../../domain/usecases/watch_current_account.dart';
import '../../messages/settings_messages.dart';

part 'delete_account_event.dart';
part 'delete_account_state.dart';

/// Exclusao da conta, confirmada pela senha e pela palavra digitada.
///
/// Com a exclusao aceita, a sessao deste aparelho termina e o roteador leva as telas de conta
/// com o aviso de conta excluida. [account], quando informado, da o e-mail da conta que sera
/// excluida, para a tela mostrar.
class DeleteAccountBloc extends Bloc<DeleteAccountEvent, DeleteAccountState> {
  DeleteAccountBloc({required this._deleteAccount, WatchCurrentAccount? account})
    : super(DeleteAccountState(email: account?.current?.email)) {
    on<DeleteAccountPasswordEdited>(_onPasswordEdited);
    on<DeleteAccountSubmitted>(_onSubmitted, transformer: droppable());
  }

  final DeleteAccount _deleteAccount;

  void _onPasswordEdited(DeleteAccountPasswordEdited event, Emitter<DeleteAccountState> emit) {
    if (state.error != null || state.formError != null) {
      emit(DeleteAccountState(status: state.status, email: state.email));
    }
  }

  Future<void> _onSubmitted(DeleteAccountSubmitted event, Emitter<DeleteAccountState> emit) async {
    if (!AccountRules.canConfirmDeletion(password: event.password, word: event.word)) {
      return;
    }
    emit(DeleteAccountState(status: FormStatus.submitting, email: state.email));
    final Result<void> result = await _deleteAccount(event.password);
    switch (result) {
      case Ok<void>():
        emit(DeleteAccountState(status: FormStatus.succeeded, email: state.email));
      case Err<void>(:final AppFailure failure):
        // Senha recusada vai para o campo; o resto avisa que nada foi apagado.
        emit(
          isPasswordRejection(failure)
              ? DeleteAccountState(error: passwordConfirmationErrorFor(failure), email: state.email)
              : DeleteAccountState(formError: failure.message, email: state.email),
        );
    }
  }
}

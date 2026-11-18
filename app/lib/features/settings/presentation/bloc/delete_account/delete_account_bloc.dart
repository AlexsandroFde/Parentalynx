import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/bloc/form_status.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../domain/services/account_rules.dart';
import '../../../domain/usecases/delete_account.dart';
import '../../messages/settings_messages.dart';

part 'delete_account_event.dart';
part 'delete_account_state.dart';

/// Exclusao da conta, confirmada pela senha e pela palavra digitada.
///
/// Com a exclusao aceita, a sessao deste aparelho termina e o roteador leva as telas de conta
/// com o aviso de conta excluida.
class DeleteAccountBloc extends Bloc<DeleteAccountEvent, DeleteAccountState> {
  DeleteAccountBloc({required this._deleteAccount}) : super(const DeleteAccountState()) {
    on<DeleteAccountPasswordEdited>(_onPasswordEdited);
    on<DeleteAccountSubmitted>(_onSubmitted, transformer: droppable());
  }

  final DeleteAccount _deleteAccount;

  void _onPasswordEdited(DeleteAccountPasswordEdited event, Emitter<DeleteAccountState> emit) {
    if (state.error != null) {
      emit(DeleteAccountState(status: state.status));
    }
  }

  Future<void> _onSubmitted(DeleteAccountSubmitted event, Emitter<DeleteAccountState> emit) async {
    if (!AccountRules.canConfirmDeletion(password: event.password, word: event.word)) {
      return;
    }
    emit(const DeleteAccountState(status: FormStatus.submitting));
    final Result<void> result = await _deleteAccount(event.password);
    switch (result) {
      case Ok<void>():
        emit(const DeleteAccountState(status: FormStatus.succeeded));
      case Err<void>(:final AppFailure failure):
        emit(DeleteAccountState(error: passwordConfirmationErrorFor(failure)));
    }
  }
}

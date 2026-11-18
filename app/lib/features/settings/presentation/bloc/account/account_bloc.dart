import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../authentication/domain/entities/guardian_account.dart';
import '../../../domain/usecases/regenerate_recovery_key.dart';
import '../../../domain/usecases/update_display_name.dart';
import '../../../domain/usecases/watch_current_account.dart';

part 'account_event.dart';
part 'account_state.dart';

/// Conta do responsavel: nome de exibicao e nova chave de recuperacao.
class AccountBloc extends Bloc<AccountEvent, AccountState> {
  AccountBloc({
    required this._watchAccount,
    required this._updateDisplayName,
    required this._regenerateRecoveryKey,
  }) : super(AccountState(account: _watchAccount.current)) {
    on<AccountStarted>(_onStarted, transformer: restartable());
    on<AccountNameSubmitted>(_onNameSubmitted, transformer: droppable());
    on<AccountRecoveryKeyRequested>(_onRecoveryKeyRequested, transformer: droppable());
    on<AccountRecoveryKeyShown>(_onRecoveryKeyShown);
  }

  final WatchCurrentAccount _watchAccount;
  final UpdateDisplayName _updateDisplayName;
  final RegenerateRecoveryKey _regenerateRecoveryKey;

  Future<void> _onStarted(AccountStarted event, Emitter<AccountState> emit) {
    return emit.forEach<GuardianAccount?>(
      _watchAccount(),
      onData: (GuardianAccount? account) => state.withAccount(account),
    );
  }

  Future<void> _onNameSubmitted(AccountNameSubmitted event, Emitter<AccountState> emit) async {
    final GuardianAccount? account = state.account;
    // Nome igual ao atual nao precisa ir ao servidor.
    if (account == null || event.name.trim() == account.displayName) {
      return;
    }
    emit(state.copyWith(command: AccountCommand.rename, action: const ActionRunning()));
    final Result<GuardianAccount> result = await _updateDisplayName(event.name);
    switch (result) {
      case Ok<GuardianAccount>():
        emit(state.copyWith(action: const ActionSucceeded(message: 'Nome alterado.')));
      case Err<GuardianAccount>(:final AppFailure failure):
        emit(state.copyWith(action: actionStatusForFailure(failure)));
    }
  }

  Future<void> _onRecoveryKeyRequested(
    AccountRecoveryKeyRequested event,
    Emitter<AccountState> emit,
  ) async {
    emit(state.copyWith(command: AccountCommand.recoveryKey, action: const ActionRunning()));
    final Result<String> result = await _regenerateRecoveryKey(event.password);
    switch (result) {
      case Ok<String>(:final String value):
        emit(state.copyWith(action: const ActionSucceeded(), recoveryKey: value));
      case Err<String>(:final AppFailure failure):
        emit(state.copyWith(action: actionStatusForFailure(failure)));
    }
  }

  void _onRecoveryKeyShown(AccountRecoveryKeyShown event, Emitter<AccountState> emit) {
    emit(state.withoutRecoveryKey());
  }
}

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../authentication/domain/entities/guardian_account.dart';
import '../../../domain/usecases/update_account_settings.dart';
import '../../../domain/usecases/watch_current_account.dart';

part 'account_settings_event.dart';
part 'account_settings_state.dart';

/// Ajustes da conta na tela de dados e privacidade: retencao e limiares dos alertas.
class AccountSettingsBloc extends Bloc<AccountSettingsEvent, AccountSettingsState> {
  AccountSettingsBloc({required this._watchAccount, required this._updateSettings})
    : super(AccountSettingsState(account: _watchAccount.current)) {
    on<AccountSettingsStarted>(_onStarted, transformer: restartable());
    on<AccountSettingsChanged>(_onChanged, transformer: droppable());
  }

  final WatchCurrentAccount _watchAccount;
  final UpdateAccountSettings _updateSettings;

  Future<void> _onStarted(AccountSettingsStarted event, Emitter<AccountSettingsState> emit) {
    return emit.forEach<GuardianAccount?>(
      _watchAccount(),
      onData: (GuardianAccount? account) => state.withAccount(account),
    );
  }

  Future<void> _onChanged(AccountSettingsChanged event, Emitter<AccountSettingsState> emit) async {
    emit(state.withAction(const ActionRunning()));
    final Result<GuardianAccount> result = await _updateSettings(event.settings);
    switch (result) {
      case Ok<GuardianAccount>():
        emit(state.withAction(const ActionSucceeded(message: 'Ajuste salvo.')));
      case Err<GuardianAccount>(:final AppFailure failure):
        emit(state.withAction(actionStatusForFailure(failure)));
    }
  }
}

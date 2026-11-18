import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../server_config/domain/usecases/watch_server_address.dart';
import '../../../../user_role/domain/entities/user_role.dart';
import '../../../../user_role/domain/usecases/change_user_role.dart';

part 'guardian_entry_event.dart';
part 'guardian_entry_state.dart';

/// Porta de entrada do modo responsavel: mostra o servidor em uso e deixa voltar para a
/// escolha de modo. Criar conta e entrar ficam nas proprias telas.
class GuardianEntryBloc extends Bloc<GuardianEntryEvent, GuardianEntryState> {
  GuardianEntryBloc({required this._watchServerAddress, required this._changeUserRole})
    : super(GuardianEntryState(serverAddress: _watchServerAddress.current)) {
    on<GuardianEntryStarted>(_onStarted, transformer: restartable());
    on<GuardianEntryRoleResetRequested>(_onRoleResetRequested, transformer: droppable());
  }

  final WatchServerAddress _watchServerAddress;
  final ChangeUserRole _changeUserRole;

  Future<void> _onStarted(GuardianEntryStarted event, Emitter<GuardianEntryState> emit) {
    return emit.forEach<String>(
      _watchServerAddress(),
      onData: (String address) => state.copyWith(serverAddress: address),
    );
  }

  Future<void> _onRoleResetRequested(
    GuardianEntryRoleResetRequested event,
    Emitter<GuardianEntryState> emit,
  ) async {
    emit(state.copyWith(roleReset: const ActionRunning()));
    final Result<void> result = await _changeUserRole(UserRole.unset);
    switch (result) {
      case Ok<void>():
        // O roteador leva para as boas-vindas.
        emit(state.copyWith(roleReset: const ActionSucceeded()));
      case Err<void>(:final AppFailure failure):
        emit(state.copyWith(roleReset: actionStatusForFailure(failure)));
    }
  }
}

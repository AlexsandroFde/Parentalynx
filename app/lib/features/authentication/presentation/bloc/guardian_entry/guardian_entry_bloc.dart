import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../user_role/domain/entities/user_role.dart';
import '../../../../user_role/domain/usecases/change_user_role.dart';

part 'guardian_entry_event.dart';
part 'guardian_entry_state.dart';

/// Porta de entrada do modo responsavel: deixa voltar para a escolha de modo. Criar conta e
/// entrar ficam nas proprias telas.
class GuardianEntryBloc extends Bloc<GuardianEntryEvent, GuardianEntryState> {
  GuardianEntryBloc({required this._changeUserRole}) : super(const GuardianEntryState()) {
    on<GuardianEntryRoleResetRequested>(_onRoleResetRequested, transformer: droppable());
  }

  final ChangeUserRole _changeUserRole;

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

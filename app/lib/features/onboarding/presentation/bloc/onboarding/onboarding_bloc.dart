import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../server_config/domain/usecases/watch_server_address.dart';
import '../../../../user_role/domain/entities/user_role.dart';
import '../../../../user_role/domain/usecases/change_user_role.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

/// Boas-vindas: a escolha do papel deste aparelho (responsavel ou crianca).
///
/// Sem um servidor configurado, a escolha espera a pessoa informar o endereco. Com o papel
/// gravado, o roteador sai das boas-vindas.
class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({required this._watchServerAddress, required this._changeUserRole})
    : super(const OnboardingState()) {
    on<OnboardingRoleChosen>(_onRoleChosen, transformer: droppable());
    on<OnboardingServerSheetClosed>(_onServerSheetClosed, transformer: droppable());
  }

  final WatchServerAddress _watchServerAddress;
  final ChangeUserRole _changeUserRole;

  Future<void> _onRoleChosen(OnboardingRoleChosen event, Emitter<OnboardingState> emit) async {
    if (state.isBusy) {
      return;
    }
    if (!_watchServerAddress.isConfigured) {
      emit(OnboardingState(awaitingServerFor: event.role));
      return;
    }
    await _choose(event.role, emit);
  }

  Future<void> _onServerSheetClosed(
    OnboardingServerSheetClosed event,
    Emitter<OnboardingState> emit,
  ) async {
    final UserRole? role = state.awaitingServerFor;
    if (role == null) {
      return;
    }
    if (!event.saved || !_watchServerAddress.isConfigured) {
      emit(const OnboardingState());
      return;
    }
    await _choose(role, emit);
  }

  Future<void> _choose(UserRole role, Emitter<OnboardingState> emit) async {
    emit(OnboardingState(choosing: role, action: const ActionRunning()));
    final Result<void> result = await _changeUserRole(role);
    switch (result) {
      case Ok<void>():
        emit(const OnboardingState(action: ActionSucceeded()));
      case Err<void>(:final AppFailure failure):
        emit(OnboardingState(action: actionStatusForFailure(failure)));
    }
  }
}

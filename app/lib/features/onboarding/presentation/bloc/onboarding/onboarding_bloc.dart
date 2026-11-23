import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../user_role/domain/entities/user_role.dart';
import '../../../../user_role/domain/usecases/change_user_role.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

/// Boas-vindas: a escolha do papel deste aparelho (responsavel ou crianca).
///
/// Com o papel gravado, o roteador sai das boas-vindas.
class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({required this._changeUserRole}) : super(const OnboardingState()) {
    on<OnboardingRoleChosen>(_onRoleChosen, transformer: droppable());
  }

  final ChangeUserRole _changeUserRole;

  Future<void> _onRoleChosen(OnboardingRoleChosen event, Emitter<OnboardingState> emit) async {
    if (state.isBusy) {
      return;
    }
    final UserRole role = event.role;
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

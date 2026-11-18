import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/bloc/form_status.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../authentication/domain/entities/guardian_account.dart';
import '../../../domain/entities/password_change_errors.dart';
import '../../../domain/services/account_rules.dart';
import '../../../domain/usecases/change_password.dart';
import '../../../domain/usecases/watch_current_account.dart';
import '../../messages/settings_messages.dart';

part 'change_password_event.dart';
part 'change_password_state.dart';

/// Formulario de troca da senha administrativa.
class ChangePasswordBloc extends Bloc<ChangePasswordEvent, ChangePasswordState> {
  ChangePasswordBloc({required this._changePassword, required WatchCurrentAccount account})
    : super(_initialState(account.current)) {
    on<ChangePasswordFieldEdited>(_onFieldEdited);
    on<ChangePasswordSubmitted>(_onSubmitted, transformer: droppable());
  }

  final ChangePassword _changePassword;

  static ChangePasswordState _initialState(GuardianAccount? account) {
    return ChangePasswordState(email: account?.email, displayName: account?.displayName);
  }

  void _onFieldEdited(ChangePasswordFieldEdited event, Emitter<ChangePasswordState> emit) {
    if (state.errors.of(event.field) != null) {
      emit(state.copyWith(errors: state.errors.without(event.field)));
    }
  }

  Future<void> _onSubmitted(
    ChangePasswordSubmitted event,
    Emitter<ChangePasswordState> emit,
  ) async {
    final PasswordChangeErrors errors = AccountRules.validatePasswordChange(
      current: event.currentPassword,
      next: event.newPassword,
      confirmation: event.confirmation,
      email: state.email,
      displayName: state.displayName,
    );
    if (!errors.isEmpty) {
      emit(state.copyWith(status: FormStatus.editing, errors: errors));
      return;
    }
    emit(state.copyWith(status: FormStatus.submitting, errors: PasswordChangeErrors.none));
    final Result<void> result = await _changePassword(
      currentPassword: event.currentPassword,
      newPassword: event.newPassword,
    );
    switch (result) {
      case Ok<void>():
        emit(state.copyWith(status: FormStatus.succeeded));
      case Err<void>(:final AppFailure failure):
        emit(state.copyWith(status: FormStatus.editing, errors: passwordChangeErrorsFor(failure)));
    }
  }
}

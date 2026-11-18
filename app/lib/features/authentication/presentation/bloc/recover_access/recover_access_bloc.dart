import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/bloc/form_status.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../domain/entities/credential_errors.dart';
import '../../../domain/entities/guardian_session.dart';
import '../../../domain/services/credentials_policy.dart';
import '../../../domain/usecases/get_sign_in_defaults.dart';
import '../../../domain/usecases/recover_access.dart';
import '../../messages/auth_messages.dart';

part 'recover_access_event.dart';
part 'recover_access_state.dart';

/// Recuperacao administrativa: troca a senha usando a chave de recuperacao.
class RecoverAccessBloc extends Bloc<RecoverAccessEvent, RecoverAccessState> {
  RecoverAccessBloc({required this._recoverAccess, required this._defaults})
    : super(const RecoverAccessState()) {
    on<RecoverAccessStarted>(_onStarted, transformer: droppable());
    on<RecoverAccessFieldEdited>(_onFieldEdited);
    on<RecoverAccessSubmitted>(_onSubmitted, transformer: droppable());
  }

  final RecoverAccess _recoverAccess;
  final GetSignInDefaults _defaults;

  Future<void> _onStarted(RecoverAccessStarted event, Emitter<RecoverAccessState> emit) async {
    final String? email = await _defaults.storedEmail();
    if (email != null) {
      emit(state.copyWith(storedEmail: email));
    }
  }

  void _onFieldEdited(RecoverAccessFieldEdited event, Emitter<RecoverAccessState> emit) {
    if (state.errors.of(event.field) != null) {
      emit(state.copyWith(errors: state.errors.without(event.field)));
    }
  }

  Future<void> _onSubmitted(RecoverAccessSubmitted event, Emitter<RecoverAccessState> emit) async {
    final CredentialErrors errors = CredentialsPolicy.validateRecovery(
      email: event.email,
      recoveryKey: event.recoveryKey,
      password: event.password,
      confirmation: event.confirmation,
    );
    if (!errors.isEmpty) {
      emit(state.copyWith(status: FormStatus.editing, errors: errors));
      return;
    }
    emit(state.copyWith(status: FormStatus.submitting, errors: CredentialErrors.none));
    final Result<AuthenticatedSession> result = await _recoverAccess(
      email: event.email,
      recoveryKey: event.recoveryKey,
      newPassword: event.password,
    );
    switch (result) {
      case Ok<AuthenticatedSession>():
        emit(state.copyWith(status: FormStatus.succeeded));
      case Err<AuthenticatedSession>(:final AppFailure failure):
        emit(state.copyWith(status: FormStatus.editing, errors: recoveryErrorsFor(failure)));
    }
  }
}

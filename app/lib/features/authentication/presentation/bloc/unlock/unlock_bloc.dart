import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/bloc/form_status.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../domain/entities/guardian_session.dart';
import '../../../domain/services/credentials_policy.dart';
import '../../../domain/usecases/get_sign_in_defaults.dart';
import '../../../domain/usecases/unlock_session.dart';
import '../../../domain/usecases/watch_guardian_session.dart';
import '../../messages/auth_messages.dart';

part 'unlock_event.dart';
part 'unlock_state.dart';

/// Tela de bloqueio do painel: confere a senha administrativa e abre o painel.
class UnlockBloc extends Bloc<UnlockEvent, UnlockState> {
  UnlockBloc({required this._unlockSession, required this._session, required this._defaults})
    : super(const UnlockState()) {
    on<UnlockStarted>(_onStarted, transformer: droppable());
    on<UnlockPasswordEdited>(_onPasswordEdited);
    on<UnlockSubmitted>(_onSubmitted, transformer: droppable());
  }

  final UnlockSession _unlockSession;
  final WatchGuardianSession _session;
  final GetSignInDefaults _defaults;

  Future<void> _onStarted(UnlockStarted event, Emitter<UnlockState> emit) async {
    final GuardianSessionState session = _session.current;
    if (session is SessionLocked && session.account != null) {
      final String name = session.account!.displayName.trim();
      emit(state.copyWith(email: session.account!.email, displayName: name.isEmpty ? null : name));
      return;
    }
    final String? stored = await _defaults.storedEmail();
    if (stored != null) {
      emit(state.copyWith(email: stored));
    }
  }

  void _onPasswordEdited(UnlockPasswordEdited event, Emitter<UnlockState> emit) {
    if (state.error != null) {
      emit(state.copyWith(clearError: true));
    }
  }

  Future<void> _onSubmitted(UnlockSubmitted event, Emitter<UnlockState> emit) async {
    final String? invalid = CredentialsPolicy.enteredPasswordError(event.password);
    if (invalid != null) {
      emit(state.copyWith(error: invalid));
      return;
    }
    emit(state.copyWith(status: FormStatus.submitting, clearError: true));
    final Result<GuardianProfile> result = await _unlockSession(event.password);
    switch (result) {
      case Ok<GuardianProfile>():
        // O roteador leva de volta para onde a pessoa estava.
        emit(state.copyWith(status: FormStatus.succeeded));
      case Err<GuardianProfile>(:final AppFailure failure):
        emit(state.copyWith(status: FormStatus.editing, error: unlockErrorFor(failure)));
    }
  }
}

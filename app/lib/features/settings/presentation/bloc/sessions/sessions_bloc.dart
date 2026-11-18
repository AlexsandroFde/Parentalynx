import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../authentication/domain/entities/guardian_session.dart';
import '../../../domain/usecases/list_guardian_sessions.dart';
import '../../../domain/usecases/revoke_guardian_session.dart';

part 'sessions_event.dart';
part 'sessions_state.dart';

/// Aparelhos de responsaveis conectados a conta, com o encerramento de sessoes.
class SessionsBloc extends Bloc<SessionsEvent, SessionsState> {
  SessionsBloc({required this._listSessions, required this._revokeSession})
    : super(const SessionsLoading()) {
    on<SessionsLoadRequested>(_onLoadRequested, transformer: restartable());
    on<SessionRevokeRequested>(_onRevokeRequested, transformer: droppable());
  }

  final ListGuardianSessions _listSessions;
  final RevokeGuardianSession _revokeSession;

  Future<void> _onLoadRequested(SessionsLoadRequested event, Emitter<SessionsState> emit) async {
    emit(const SessionsLoading());
    final Result<List<GuardianSessionInfo>> result = await _listSessions();
    switch (result) {
      case Ok<List<GuardianSessionInfo>>(:final List<GuardianSessionInfo> value):
        emit(SessionsLoaded(sessions: value));
      case Err<List<GuardianSessionInfo>>(:final AppFailure failure):
        emit(SessionsError(failure));
    }
  }

  Future<void> _onRevokeRequested(SessionRevokeRequested event, Emitter<SessionsState> emit) async {
    final SessionsState current = state;
    if (current is! SessionsLoaded) {
      return;
    }
    emit(current.copyWith(action: const ActionRunning()));
    final Result<void> result = await _revokeSession(event.sessionId);
    if (result case Err<void>(:final AppFailure failure)) {
      emit(current.copyWith(action: actionStatusForFailure(failure)));
      return;
    }
    // A lista e recarregada; sem rede, so tira a sessao encerrada da lista atual.
    final List<GuardianSessionInfo> sessions =
        (await _listSessions()).valueOrNull ??
        <GuardianSessionInfo>[
          for (final GuardianSessionInfo session in current.sessions)
            if (session.id != event.sessionId) session,
        ];
    emit(
      SessionsLoaded(
        sessions: sessions,
        action: const ActionSucceeded(message: 'Sessão encerrada.'),
      ),
    );
  }
}

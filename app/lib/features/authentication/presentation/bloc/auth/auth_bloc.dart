import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/time/clock.dart';
import '../../../domain/entities/guardian_account.dart';
import '../../../domain/entities/guardian_session.dart';
import '../../../domain/usecases/acknowledge_recovery_key.dart';
import '../../../domain/usecases/end_session.dart';
import '../../../domain/usecases/lock_session.dart';
import '../../../domain/usecases/refresh_account.dart';
import '../../../domain/usecases/sign_out.dart';
import '../../../domain/usecases/watch_guardian_session.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Autenticacao e sessao do responsavel neste aparelho.
///
/// Espelha a sessao do dominio (sem sessao, bloqueada, aberta), que e alterada pelos casos
/// de uso: os formularios de conta abrem a sessao, este BLoC bloqueia por inatividade e
/// encerra quando o servidor recusa a sessao. O roteador observa este BLoC para decidir entre
/// as telas de conta, a tela de bloqueio e o painel.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required this._watchSession,
    required this._lockSession,
    required this._signOut,
    required this._endSession,
    required this._acknowledgeRecoveryKey,
    required this._refreshAccount,
    required this._clock,
  }) : super(AuthState.fromSession(_watchSession.current)) {
    on<AuthSubscriptionRequested>(_onSubscriptionRequested, transformer: restartable());
    on<AuthAppPaused>(_onAppPaused);
    on<AuthAppResumed>(_onAppResumed, transformer: sequential());
    on<AuthLockRequested>(_onLockRequested);
    on<AuthSignOutRequested>(_onSignOutRequested, transformer: droppable());
    on<AuthRecoveryKeyAcknowledged>(_onRecoveryKeyAcknowledged);
    on<AuthAccountRefreshRequested>(_onAccountRefreshRequested, transformer: droppable());
  }

  final WatchGuardianSession _watchSession;
  final LockSession _lockSession;
  final SignOut _signOut;
  final EndSession _endSession;
  final AcknowledgeRecoveryKey _acknowledgeRecoveryKey;
  final RefreshAccount _refreshAccount;
  final Clock _clock;

  /// Momento em que o app foi para o segundo plano. So serve para o bloqueio por inatividade
  /// e nao faz parte do estado da tela.
  DateTime? _backgroundedAt;

  Future<void> _onSubscriptionRequested(
    AuthSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) async {
    await Future.wait(<Future<void>>[
      emit.forEach<GuardianSessionState>(_watchSession(), onData: AuthState.fromSession),
      // O servidor recusou a sessao: encerra a sessao local com o aviso correspondente.
      emit.onEach<void>(
        _watchSession.rejections(),
        onData: (_) => unawaited(_endSession(SessionEndReason.expired)),
      ),
    ]);
  }

  void _onAppPaused(AuthAppPaused event, Emitter<AuthState> emit) {
    _backgroundedAt ??= _clock.now();
  }

  Future<void> _onAppResumed(AuthAppResumed event, Emitter<AuthState> emit) async {
    final DateTime? since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null) {
      return;
    }
    await _lockSession.afterInactivity(_clock.now().difference(since));
  }

  void _onLockRequested(AuthLockRequested event, Emitter<AuthState> emit) => _lockSession();

  Future<void> _onSignOutRequested(AuthSignOutRequested event, Emitter<AuthState> emit) async {
    _backgroundedAt = null;
    await _signOut();
  }

  void _onRecoveryKeyAcknowledged(AuthRecoveryKeyAcknowledged event, Emitter<AuthState> emit) {
    _acknowledgeRecoveryKey();
  }

  Future<void> _onAccountRefreshRequested(
    AuthAccountRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Sem rede a conta em memoria continua; sessao recusada chega pelo aviso do servidor.
    await _refreshAccount();
  }
}

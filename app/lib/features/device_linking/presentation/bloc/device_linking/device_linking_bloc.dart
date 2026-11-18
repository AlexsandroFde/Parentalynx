import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../../core/time/clock.dart';
import '../../../../device_sync/domain/entities/realtime_update.dart';
import '../../../../device_sync/domain/usecases/watch_realtime_updates.dart';
import '../../../domain/entities/link_code.dart';
import '../../../domain/entities/link_request.dart';
import '../../../domain/entities/linking_overview.dart';
import '../../../domain/usecases/approve_link_request.dart';
import '../../../domain/usecases/cancel_link_code.dart';
import '../../../domain/usecases/check_link_requests.dart';
import '../../../domain/usecases/expire_link_code.dart';
import '../../../domain/usecases/generate_link_code.dart';
import '../../../domain/usecases/get_shown_link_code.dart';
import '../../../domain/usecases/reject_link_request.dart';

part 'device_linking_event.dart';
part 'device_linking_state.dart';

/// Vinculacao de um aparelho da crianca vista pelo responsavel: gera o codigo, acompanha os
/// pedidos (aviso em tempo real e consulta periodica) e aprova ou rejeita.
///
/// O codigo gerado fica guardado no repositorio enquanto o app estiver aberto, entao continua
/// na tela quando a pessoa sai da pagina e volta.
class DeviceLinkingBloc extends Bloc<DeviceLinkingEvent, DeviceLinkingState> {
  DeviceLinkingBloc({
    required GetShownLinkCode getShownCode,
    required this._checkRequests,
    required this._generateCode,
    required this._cancelCode,
    required this._expireCode,
    required this._approve,
    required this._reject,
    required this._watchRealtimeUpdates,
    required this._clock,
  }) : super(DeviceLinkingState(nowMs: _clock.nowMs(), code: getShownCode())) {
    on<DeviceLinkingStarted>(_onStarted, transformer: restartable());
    on<LinkRequestsCheckRequested>(_onCheckRequested, transformer: restartable());
    on<LinkCodeTicked>(_onTicked);
    on<LinkCodeRequested>(_onCodeRequested, transformer: droppable());
    on<LinkCodeCancelRequested>(_onCancelRequested, transformer: droppable());
    on<LinkApprovalSubmitted>(_onApprovalSubmitted, transformer: droppable());
    on<LinkRejectionSubmitted>(_onRejectionSubmitted, transformer: droppable());
    on<ApprovedLinkDismissed>(_onApprovedDismissed);
  }

  final CheckLinkRequests _checkRequests;
  final GenerateLinkCode _generateCode;
  final CancelLinkCode _cancelCode;
  final ExpireLinkCode _expireCode;
  final ApproveLinkRequest _approve;
  final RejectLinkRequest _reject;
  final WatchRealtimeUpdates _watchRealtimeUpdates;
  final Clock _clock;

  Future<void> _onStarted(DeviceLinkingStarted event, Emitter<DeviceLinkingState> emit) {
    add(const LinkRequestsCheckRequested());
    // Um aviso de pedido novo ou resolvido dispara a consulta na hora.
    return emit.onEach<RealtimeUpdate>(
      _watchRealtimeUpdates(),
      onData: (RealtimeUpdate update) {
        if (update is LinkRequested || update is LinkResolved) {
          add(const LinkRequestsCheckRequested());
        }
      },
    );
  }

  Future<void> _onCheckRequested(
    LinkRequestsCheckRequested event,
    Emitter<DeviceLinkingState> emit,
  ) async {
    final Result<LinkingSnapshot> result = await _checkRequests(previous: state.requests);
    switch (result) {
      case Ok<LinkingSnapshot>(:final LinkingSnapshot value) when value.codeChangedMeanwhile:
        emit(state.copyWith(requests: value.requests, loaded: true, offline: false));
      case Ok<LinkingSnapshot>(:final LinkingSnapshot value):
        emit(
          state.copyWith(
            code: () => value.shownCode,
            otherCodeExpiresAt: () => value.otherCodeExpiresAt,
            requests: value.requests,
            loaded: true,
            offline: false,
          ),
        );
      case Err<LinkingSnapshot>(:final AppFailure failure):
        // Outras falhas ficam em silencio: a consulta seguinte tenta de novo.
        if (failure is NetworkFailure) {
          emit(state.copyWith(offline: true));
        }
    }
  }

  void _onTicked(LinkCodeTicked event, Emitter<DeviceLinkingState> emit) {
    final int now = _clock.nowMs();
    final LinkCode? code = state.code;
    if (code != null && _expireCode(code, nowMs: now)) {
      emit(state.copyWith(nowMs: now, code: () => null, codeExpired: true));
    } else if (code != null || state.otherCodeExpiresAt != null) {
      emit(state.copyWith(nowMs: now));
    }
  }

  Future<void> _onCodeRequested(LinkCodeRequested event, Emitter<DeviceLinkingState> emit) async {
    emit(state.copyWith(command: LinkingCommand.generate, action: const ActionRunning()));
    final Result<LinkCode> result = await _generateCode();
    switch (result) {
      case Ok<LinkCode>(:final LinkCode value):
        emit(
          state.copyWith(
            nowMs: _clock.nowMs(),
            code: () => value,
            otherCodeExpiresAt: () => null,
            approved: () => null,
            codeExpired: false,
            action: const ActionSucceeded(),
          ),
        );
      case Err<LinkCode>(:final AppFailure failure):
        emit(state.copyWith(action: actionStatusForFailure(failure)));
    }
  }

  Future<void> _onCancelRequested(
    LinkCodeCancelRequested event,
    Emitter<DeviceLinkingState> emit,
  ) async {
    final LinkCode? code = state.code;
    if (code == null) {
      return;
    }
    emit(state.copyWith(command: LinkingCommand.cancel, action: const ActionRunning()));
    final Result<void> result = await _cancelCode(code.id);
    switch (result) {
      case Ok<void>():
        emit(state.copyWith(code: () => null, codeExpired: false, action: const ActionSucceeded()));
      case Err<void>(:final AppFailure failure):
        emit(state.copyWith(action: actionStatusForFailure(failure)));
    }
  }

  Future<void> _onApprovalSubmitted(
    LinkApprovalSubmitted event,
    Emitter<DeviceLinkingState> emit,
  ) async {
    emit(
      state.copyWith(
        command: LinkingCommand.approve,
        actingOn: () => event.requestId,
        action: const ActionRunning(),
      ),
    );
    final Result<LinkRequest> result = await _approve(event.requestId, childName: event.childName);
    switch (result) {
      case Ok<LinkRequest>(:final LinkRequest value):
        emit(
          state.copyWith(
            requests: _without(event.requestId),
            approved: () => value,
            action: const ActionSucceeded(),
          ),
        );
      case Err<LinkRequest>(:final AppFailure failure):
        emit(state.copyWith(action: actionStatusForFailure(failure)));
    }
  }

  Future<void> _onRejectionSubmitted(
    LinkRejectionSubmitted event,
    Emitter<DeviceLinkingState> emit,
  ) async {
    emit(
      state.copyWith(
        command: LinkingCommand.reject,
        actingOn: () => event.requestId,
        action: const ActionRunning(),
      ),
    );
    final Result<void> result = await _reject(event.requestId);
    switch (result) {
      case Ok<void>():
        emit(
          state.copyWith(
            requests: _without(event.requestId),
            action: const ActionSucceeded(message: 'Pedido rejeitado.'),
          ),
        );
      case Err<void>(:final AppFailure failure):
        emit(state.copyWith(action: actionStatusForFailure(failure)));
    }
  }

  void _onApprovedDismissed(ApprovedLinkDismissed event, Emitter<DeviceLinkingState> emit) {
    emit(state.copyWith(approved: () => null));
  }

  List<LinkRequest> _without(String requestId) {
    return <LinkRequest>[
      for (final LinkRequest request in state.requests)
        if (request.id != requestId) request,
    ];
  }
}

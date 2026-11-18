import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../device_linking/domain/entities/link_state.dart';
import '../../../../device_linking/domain/usecases/report_agent_inactive.dart';
import '../../../../device_linking/domain/usecases/watch_link_state.dart';
import '../../../domain/entities/agent_status.dart';
import '../../../domain/usecases/ensure_agent_running.dart';
import '../../../domain/usecases/get_agent_status.dart';
import '../../services/foreground_tracker.dart';

part 'child_device_status_event.dart';
part 'child_device_status_state.dart';

/// Retrato do agente para as telas do modo crianca, atualizado a cada [pollInterval] enquanto
/// o aparelho esta vinculado e o app esta em primeiro plano.
///
/// O tempo restante vem pronto do lado nativo a cada consulta, entao a contagem regressiva da
/// tela acompanha a contagem real, sem relogio paralelo no Dart. Tambem religa o servico do
/// agente quando o aparelho fica vinculado e quando o app volta ao primeiro plano, e avisa
/// quando o agente deixou de estar ativo (o responsavel removeu o vinculo).
class ChildDeviceStatusBloc extends Bloc<ChildDeviceStatusEvent, ChildDeviceStatusState> {
  ChildDeviceStatusBloc({
    required this._getAgentStatus,
    required this._ensureAgentRunning,
    required this._watchLinkState,
    required this._reportAgentInactive,
    required this._foreground,
    this.pollInterval = const Duration(seconds: 1),
  }) : super(const ChildDeviceStatusInitial()) {
    on<ChildDeviceStatusStarted>(_onStarted, transformer: restartable());
    on<ChildDeviceStatusRefreshRequested>(_onRefreshRequested, transformer: droppable());
    on<ChildDeviceStatusAppResumed>(_onAppResumed, transformer: droppable());
  }

  final GetAgentStatus _getAgentStatus;
  final EnsureAgentRunning _ensureAgentRunning;
  final WatchLinkState _watchLinkState;
  final ReportAgentInactive _reportAgentInactive;
  final ForegroundTracker _foreground;

  /// Intervalo entre as consultas ao agente.
  final Duration pollInterval;

  Timer? _timer;
  bool _linked = false;

  Future<void> _onStarted(ChildDeviceStatusStarted event, Emitter<ChildDeviceStatusState> emit) {
    return emit.onEach<LinkState>(
      _watchLinkState(),
      onData: (LinkState link) {
        final bool linked = link.phase.isLinked;
        if (linked == _linked) {
          return;
        }
        _linked = linked;
        if (linked) {
          // O agente acabou de ser ligado ou o app abriu com o aparelho vinculado.
          unawaited(_ensureAgentRunning());
          emit(const ChildDeviceStatusLoading());
          _startPolling();
          add(const ChildDeviceStatusRefreshRequested(force: true));
        } else {
          _stopPolling();
          emit(const ChildDeviceStatusInitial());
        }
      },
    );
  }

  Future<void> _onRefreshRequested(
    ChildDeviceStatusRefreshRequested event,
    Emitter<ChildDeviceStatusState> emit,
  ) async {
    if (!_linked || (!event.force && !_foreground.isForeground)) {
      return;
    }
    if (event.force && state is ChildDeviceStatusFailure) {
      emit(const ChildDeviceStatusLoading());
    }
    final Result<AgentStatus> result = await _getAgentStatus();
    if (!_linked) {
      return;
    }
    switch (result) {
      case Ok<AgentStatus>(value: final AgentStatus status):
        emit(ChildDeviceStatusLoaded(status));
        if (!status.active) {
          _reportAgentInactive();
        }
      case Err<AgentStatus>(:final AppFailure failure):
        // Falha passageira: mantem o ultimo retrato na tela. So mostra o erro se nao ha
        // nenhum.
        if (state is! ChildDeviceStatusLoaded) {
          emit(ChildDeviceStatusFailure(failure));
        }
    }
  }

  Future<void> _onAppResumed(
    ChildDeviceStatusAppResumed event,
    Emitter<ChildDeviceStatusState> emit,
  ) async {
    if (_linked) {
      await _ensureAgentRunning();
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (Timer timer) {
      add(const ChildDeviceStatusRefreshRequested());
    });
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}

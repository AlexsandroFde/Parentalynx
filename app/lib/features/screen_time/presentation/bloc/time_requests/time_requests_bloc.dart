import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/action_status.dart';
import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../../core/time/formatters.dart';
import '../../../../child_device/domain/entities/child_device.dart';
import '../../../../child_device/domain/usecases/refresh_child_devices.dart';
import '../../../../child_device/domain/usecases/watch_child_devices.dart';
import '../../../../device_sync/domain/entities/realtime_update.dart';
import '../../../../device_sync/domain/usecases/watch_realtime_updates.dart';
import '../../../domain/entities/time_request.dart';
import '../../../domain/usecases/approve_time_request.dart';
import '../../../domain/usecases/deny_time_request.dart';
import '../../../domain/usecases/list_time_requests.dart';

part 'time_requests_event.dart';
part 'time_requests_state.dart';

/// Pedidos de tempo adicional de todos os aparelhos ativos: responder os pendentes e
/// consultar os ja respondidos.
///
/// Recarrega quando a lista de aparelhos ativos muda e quando chega um aviso de pedido novo.
class TimeRequestsBloc extends Bloc<TimeRequestsEvent, TimeRequestsState> {
  TimeRequestsBloc({
    required this._listTimeRequests,
    required this._approveTimeRequest,
    required this._denyTimeRequest,
    required this._watchDevices,
    required this._refreshDevices,
    required this._watchRealtimeUpdates,
  }) : super(const TimeRequestsLoading()) {
    on<TimeRequestsStarted>(_onStarted, transformer: restartable());
    on<_TimeRequestsDevicesChanged>(_onDevicesChanged, transformer: restartable());
    on<TimeRequestsRefreshRequested>(_onRefreshRequested, transformer: droppable());
    on<TimeRequestApproved>(_onApproved, transformer: droppable());
    on<TimeRequestDenied>(_onDenied, transformer: droppable());
  }

  final ListTimeRequests _listTimeRequests;
  final ApproveTimeRequest _approveTimeRequest;
  final DenyTimeRequest _denyTimeRequest;
  final WatchChildDevices _watchDevices;
  final RefreshChildDevices _refreshDevices;
  final WatchRealtimeUpdates _watchRealtimeUpdates;

  /// Aparelhos ativos da ultima lista conhecida.
  List<String> _deviceIds = const <String>[];

  Future<void> _onStarted(TimeRequestsStarted event, Emitter<TimeRequestsState> emit) async {
    emit(const TimeRequestsLoading());
    if (_watchDevices.cached == null) {
      final Result<List<ChildDevice>> devices = await _refreshDevices();
      if (devices case Err<List<ChildDevice>>(:final AppFailure failure)) {
        emit(TimeRequestsError(failure));
        return;
      }
    }
    await Future.wait(<Future<void>>[
      emit.onEach<List<String>>(
        _watchDevices().map(_activeIds).distinct(const ListEquality<String>().equals),
        onData: (List<String> ids) => add(_TimeRequestsDevicesChanged(ids)),
      ),
      emit.onEach<RealtimeUpdate>(
        _watchRealtimeUpdates().where((RealtimeUpdate update) => update is TimeRequestReceived),
        onData: (RealtimeUpdate update) => add(const TimeRequestsRefreshRequested()),
      ),
    ]);
  }

  Future<void> _onDevicesChanged(
    _TimeRequestsDevicesChanged event,
    Emitter<TimeRequestsState> emit,
  ) async {
    _deviceIds = event.deviceIds;
    await _reload(emit, keepOnFailure: state is TimeRequestsLoaded || state is TimeRequestsEmpty);
  }

  Future<void> _onRefreshRequested(
    TimeRequestsRefreshRequested event,
    Emitter<TimeRequestsState> emit,
  ) async {
    try {
      await _reload(emit, keepOnFailure: true);
    } finally {
      event.completer?.complete();
    }
  }

  Future<void> _onApproved(TimeRequestApproved event, Emitter<TimeRequestsState> emit) {
    final String who = _who(event.request);
    return _resolve(
      emit,
      event.request,
      () => _approveTimeRequest(event.request.id, minutes: event.minutes),
      success:
          '${formatMinutes(event.minutes)} a mais para $who hoje. O aparelho recebe em instantes.',
    );
  }

  Future<void> _onDenied(TimeRequestDenied event, Emitter<TimeRequestsState> emit) {
    return _resolve(
      emit,
      event.request,
      () => _denyTimeRequest(event.request.id),
      success: 'Pedido negado. ${_who(event.request)} recebe o aviso.',
    );
  }

  Future<void> _resolve(
    Emitter<TimeRequestsState> emit,
    TimeRequest request,
    Future<Result<TimeRequest>> Function() operation, {
    required String success,
  }) async {
    final TimeRequestsState current = state;
    if (current is! TimeRequestsLoaded || current.resolvingId != null) {
      return;
    }
    emit(current.copyWith(resolvingId: request.id, action: const ActionRunning()));
    final Result<TimeRequest> result = await operation();
    final TimeRequestsState latest = state;
    if (latest is! TimeRequestsLoaded) {
      return;
    }
    switch (result) {
      case Ok<TimeRequest>(:final TimeRequest value):
        emit(
          latest.copyWith(
            requests: <TimeRequest>[
              for (final TimeRequest item in latest.requests) item.id == value.id ? value : item,
            ],
            clearResolving: true,
            action: ActionSucceeded(message: success),
          ),
        );
      case Err<TimeRequest>(:final AppFailure failure):
        emit(latest.copyWith(clearResolving: true, action: actionStatusForFailure(failure)));
    }
  }

  /// Busca os pedidos. Com [keepOnFailure], uma falha mantem a lista que esta na tela.
  Future<void> _reload(Emitter<TimeRequestsState> emit, {required bool keepOnFailure}) async {
    final Result<List<TimeRequest>> result = await _listTimeRequests(_deviceIds);
    switch (result) {
      case Ok<List<TimeRequest>>(:final List<TimeRequest> value):
        final TimeRequestsState current = state;
        if (value.isEmpty) {
          emit(const TimeRequestsEmpty());
        } else if (current is TimeRequestsLoaded) {
          emit(current.copyWith(requests: value));
        } else {
          emit(TimeRequestsLoaded(requests: value));
        }
      case Err<List<TimeRequest>>(:final AppFailure failure):
        if (!keepOnFailure) {
          emit(TimeRequestsError(failure));
        }
    }
  }

  static List<String> _activeIds(List<ChildDevice> devices) {
    return <String>[
      for (final ChildDevice device in devices)
        if (device.isActive) device.id,
    ];
  }

  static String _who(TimeRequest request) {
    return request.childName.isEmpty ? 'A criança' : request.childName;
  }
}

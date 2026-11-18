import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../device_sync/domain/entities/realtime_update.dart';
import '../../../../device_sync/domain/usecases/watch_realtime_updates.dart';
import '../../../domain/entities/child_device.dart';
import '../../../domain/usecases/refresh_child_devices.dart';
import '../../../domain/usecases/watch_child_devices.dart';

part 'devices_event.dart';
part 'devices_state.dart';

/// Aparelhos da conta e o aparelho em foco no painel, nas regras e nos relatorios.
///
/// A lista vem do repositorio (fonte unica de verdade): quando outra funcionalidade altera um
/// aparelho (aprovar vinculo, salvar regras, responder pedido de tempo), o repositorio avisa
/// e este BLoC acompanha, sem que elas conversem com ele.
class DevicesBloc extends Bloc<DevicesEvent, DevicesState> {
  DevicesBloc({
    required this._watchDevices,
    required this._refreshDevices,
    required this._watchRealtimeUpdates,
    this.realtimeDebounce = const Duration(milliseconds: 400),
  }) : super(const DevicesInitial()) {
    on<DevicesStarted>(_onStarted, transformer: restartable());
    on<DevicesRefreshRequested>(_onRefreshRequested, transformer: droppable());
    on<DevicesRealtimeChanged>(
      _onRealtimeChanged,
      transformer: debounceRestartable(realtimeDebounce),
    );
    on<DeviceSelected>(_onDeviceSelected);
  }

  final WatchChildDevices _watchDevices;
  final RefreshChildDevices _refreshDevices;
  final WatchRealtimeUpdates _watchRealtimeUpdates;

  /// Espera para juntar avisos em tempo real seguidos em uma unica recarga.
  final Duration realtimeDebounce;

  Future<void> _onStarted(DevicesStarted event, Emitter<DevicesState> emit) async {
    final List<ChildDevice>? cached = _watchDevices.cached;
    if (cached == null) {
      emit(const DevicesLoading());
    }
    add(const DevicesRefreshRequested());
    await Future.wait(<Future<void>>[
      emit.forEach<List<ChildDevice>>(_watchDevices(), onData: _stateFor),
      emit.onEach<RealtimeUpdate>(
        _watchRealtimeUpdates.affectingDevices(),
        onData: (RealtimeUpdate update) => add(const DevicesRealtimeChanged()),
      ),
    ]);
  }

  Future<void> _onRefreshRequested(
    DevicesRefreshRequested event,
    Emitter<DevicesState> emit,
  ) async {
    try {
      if (state is DevicesError) {
        emit(const DevicesLoading());
      }
      final Result<List<ChildDevice>> result = await _refreshDevices();
      // Sucesso chega pela lista observada. Falha so aparece se nao ha nada na tela: uma
      // atualizacao em segundo plano que falha mantem a lista anterior.
      if (result case Err<List<ChildDevice>>(:final AppFailure failure)) {
        if (state is DevicesLoading || state is DevicesInitial) {
          emit(DevicesError(failure));
        }
      }
    } finally {
      event.completer?.complete();
    }
  }

  Future<void> _onRealtimeChanged(DevicesRealtimeChanged event, Emitter<DevicesState> emit) async {
    await _refreshDevices();
  }

  void _onDeviceSelected(DeviceSelected event, Emitter<DevicesState> emit) {
    final DevicesState current = state;
    if (current is DevicesLoaded) {
      emit(current.copyWith(selectedId: event.deviceId));
    }
  }

  DevicesState _stateFor(List<ChildDevice> devices) {
    if (devices.isEmpty) {
      return const DevicesEmpty();
    }
    final DevicesState current = state;
    return DevicesLoaded(
      devices: devices,
      selectedId: current is DevicesLoaded ? current.selectedId : null,
    );
  }
}

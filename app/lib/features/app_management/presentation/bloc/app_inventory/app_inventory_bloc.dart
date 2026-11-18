import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../child_device/domain/entities/child_device.dart';
import '../../../../child_device/domain/usecases/watch_child_devices.dart';
import '../../../domain/entities/app_entry.dart';
import '../../../domain/entities/app_list_filter.dart';
import '../../../domain/usecases/get_device_apps.dart';

part 'app_inventory_event.dart';
part 'app_inventory_state.dart';

/// Inventario de apps de um aparelho para as telas de regras, com a busca e os filtros.
///
/// Recarrega em segundo plano quando o aparelho sincroniza de novo, para os tempos de uso
/// acompanharem o painel.
class AppInventoryBloc extends Bloc<AppInventoryEvent, AppInventoryState> {
  AppInventoryBloc({required this._getDeviceApps, required this._watchDevices})
    : super(const AppInventoryLoading(filter: AppListFilter())) {
    on<AppInventoryStarted>(_onStarted, transformer: restartable());
    on<AppInventoryRetryRequested>(_onRetryRequested, transformer: restartable());
    on<_AppInventoryDeviceSynced>(_onDeviceSynced, transformer: restartable());
    on<AppListQueryChanged>(
      (AppListQueryChanged event, Emitter<AppInventoryState> emit) =>
          emit(state.withFilter(state.filter.copyWith(query: event.query))),
    );
    on<AppListStateFilterChanged>(
      (AppListStateFilterChanged event, Emitter<AppInventoryState> emit) =>
          emit(state.withFilter(state.filter.copyWith(state: event.filter))),
    );
    on<AppListCategoryChanged>(
      (AppListCategoryChanged event, Emitter<AppInventoryState> emit) => emit(
        state.withFilter(
          state.filter.copyWith(category: event.category, allCategories: event.category == null),
        ),
      ),
    );
  }

  final GetDeviceApps _getDeviceApps;
  final WatchChildDevices _watchDevices;
  String? _deviceId;

  Future<void> _onStarted(AppInventoryStarted event, Emitter<AppInventoryState> emit) async {
    _deviceId = event.deviceId;
    emit(AppInventoryLoading(filter: AppListFilter(category: event.initialCategory)));
    await _load(emit, keepOnFailure: false);
    // A primeira sincronizacao observada e a que acabou de ser carregada.
    await emit.onEach<int?>(
      _watchDevices
          .device(event.deviceId)
          .map((ChildDevice? device) => device?.lastSyncAt)
          .distinct()
          .skip(1),
      onData: (int? syncedAt) => add(const _AppInventoryDeviceSynced()),
    );
  }

  Future<void> _onRetryRequested(
    AppInventoryRetryRequested event,
    Emitter<AppInventoryState> emit,
  ) async {
    emit(AppInventoryLoading(filter: state.filter));
    await _load(emit, keepOnFailure: false);
  }

  Future<void> _onDeviceSynced(_AppInventoryDeviceSynced event, Emitter<AppInventoryState> emit) {
    return _load(emit, keepOnFailure: true);
  }

  Future<void> _load(Emitter<AppInventoryState> emit, {required bool keepOnFailure}) async {
    final String? deviceId = _deviceId;
    if (deviceId == null) {
      return;
    }
    final Result<DeviceApps> result = await _getDeviceApps(deviceId);
    switch (result) {
      case Ok<DeviceApps>(:final DeviceApps value):
        emit(AppInventoryLoaded(inventory: value, filter: state.filter));
      case Err<DeviceApps>(:final AppFailure failure):
        if (!keepOnFailure || state is! AppInventoryLoaded) {
          emit(AppInventoryError(failure: failure, filter: state.filter));
        }
    }
  }
}

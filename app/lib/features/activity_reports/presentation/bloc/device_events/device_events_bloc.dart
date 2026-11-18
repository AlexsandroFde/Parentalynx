import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/event_transformers.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/time/clock.dart';
import '../../../../../core/time/formatters.dart';
import '../../../domain/entities/device_event.dart';
import '../../../domain/entities/event_group.dart';
import '../../../domain/entities/report_period.dart';
import '../../../domain/usecases/list_device_events.dart';
import '../paging/paged_list.dart';

part 'device_events_event.dart';
part 'device_events_state.dart';

/// Eventos registrados pelo aparelho no periodo, com filtro por grupo, troca de periodo e
/// paginacao.
class DeviceEventsBloc extends Bloc<DeviceEventsEvent, DeviceEventsState> {
  DeviceEventsBloc({required this._listDeviceEvents, required this._clock})
    : super(const DeviceEventsState()) {
    on<DeviceEventsStarted>(_onStarted, transformer: restartable());
    on<DeviceEventsGroupSelected>(_onGroupSelected, transformer: restartable());
    on<DeviceEventsPeriodChanged>(_onPeriodChanged, transformer: restartable());
    on<DeviceEventsRefreshRequested>(_onRefreshRequested, transformer: droppable());
    on<DeviceEventsMoreRequested>(_onMoreRequested, transformer: droppable());
    on<DeviceEventsRetried>(_onRetried, transformer: droppable());
  }

  final ListDeviceEvents _listDeviceEvents;
  final Clock _clock;

  String? _deviceId;
  String _today = '';
  String _from = '';
  String _to = '';

  Future<void> _onStarted(DeviceEventsStarted event, Emitter<DeviceEventsState> emit) async {
    _today = quotaDayOf(event.deviceToday, _clock.now());
    _deviceId = event.deviceId;
    _from = event.from ?? addDays(_today, -6);
    _to = event.to ?? _today;
    await _reload(emit, event.group ?? state.group);
  }

  Future<void> _onGroupSelected(
    DeviceEventsGroupSelected event,
    Emitter<DeviceEventsState> emit,
  ) async {
    if (event.group != state.group) {
      await _reload(emit, event.group);
    }
  }

  Future<void> _onPeriodChanged(
    DeviceEventsPeriodChanged event,
    Emitter<DeviceEventsState> emit,
  ) async {
    final ReportPeriod period = ReportPeriod.custom(event.from, event.to, today: _today);
    _from = period.from;
    _to = period.to;
    await _reload(emit, state.group);
  }

  Future<void> _onRefreshRequested(
    DeviceEventsRefreshRequested event,
    Emitter<DeviceEventsState> emit,
  ) async {
    final EventGroup group = state.group;
    final String from = _from;
    final String to = _to;
    final PageLoader<DeviceEvent>? load = _loader(group);
    if (load == null) {
      event.completer?.complete(null);
      return;
    }
    final PagedListState<DeviceEvent> next = await PagedList.first<DeviceEvent>(load);
    final AppFailure? failure = next is PagedListError<DeviceEvent> ? next.failure : null;
    // Um filtro ou periodo escolhido durante a recarga vale mais que ela; uma falha mantem a
    // lista que ja estava na tela.
    final bool outdated = state.group != group || _from != from || _to != to;
    if (!outdated && (failure == null || state.list is! PagedListLoaded<DeviceEvent>)) {
      emit(state.copyWith(list: next));
    }
    event.completer?.complete(failure);
  }

  Future<void> _onMoreRequested(
    DeviceEventsMoreRequested event,
    Emitter<DeviceEventsState> emit,
  ) async {
    await _loadMore(emit);
  }

  Future<void> _onRetried(DeviceEventsRetried event, Emitter<DeviceEventsState> emit) async {
    final PagedListState<DeviceEvent> list = state.list;
    if (list is PagedListLoaded<DeviceEvent>) {
      await _loadMore(emit);
    } else {
      await _reload(emit, state.group);
    }
  }

  Future<void> _reload(Emitter<DeviceEventsState> emit, EventGroup group) async {
    final PageLoader<DeviceEvent>? load = _loader(group);
    if (load == null) {
      return;
    }
    emit(DeviceEventsState(group: group, from: _from, to: _to));
    emit(state.copyWith(list: await PagedList.first<DeviceEvent>(load)));
  }

  Future<void> _loadMore(Emitter<DeviceEventsState> emit) async {
    final PagedListLoaded<DeviceEvent>? loading = PagedList.startMore<DeviceEvent>(state.list);
    final PageLoader<DeviceEvent>? load = _loader(state.group);
    if (loading == null || load == null) {
      return;
    }
    emit(state.copyWith(list: loading));
    emit(state.copyWith(list: await PagedList.more<DeviceEvent>(loading, load)));
  }

  PageLoader<DeviceEvent>? _loader(EventGroup group) {
    final String? deviceId = _deviceId;
    if (deviceId == null) {
      return null;
    }
    final String from = _from;
    final String to = _to;
    return (String? before) {
      return _listDeviceEvents(deviceId, from: from, to: to, group: group, before: before);
    };
  }
}

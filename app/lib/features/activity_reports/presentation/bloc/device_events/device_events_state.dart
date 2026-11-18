part of 'device_events_bloc.dart';

/// Eventos do aparelho no periodo, com o filtro por grupo.
final class DeviceEventsState extends Equatable {
  const DeviceEventsState({
    this.group = EventGroup.all,
    this.list = const PagedListLoading<DeviceEvent>(),
  });

  final EventGroup group;
  final PagedListState<DeviceEvent> list;

  DeviceEventsState copyWith({EventGroup? group, PagedListState<DeviceEvent>? list}) {
    return DeviceEventsState(group: group ?? this.group, list: list ?? this.list);
  }

  @override
  List<Object?> get props => <Object?>[group, list];
}

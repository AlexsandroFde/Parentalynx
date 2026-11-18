part of 'device_events_bloc.dart';

/// Eventos do aparelho no periodo, com o filtro por grupo.
final class DeviceEventsState extends Equatable {
  const DeviceEventsState({
    this.group = EventGroup.all,
    this.list = const PagedListLoading<DeviceEvent>(),
    this.from = '',
    this.to = '',
  });

  final EventGroup group;
  final PagedListState<DeviceEvent> list;

  /// Periodo consultado (AAAA-MM-DD), vazio antes de a tela abrir.
  final String from;
  final String to;

  DeviceEventsState copyWith({EventGroup? group, PagedListState<DeviceEvent>? list}) {
    return DeviceEventsState(
      group: group ?? this.group,
      list: list ?? this.list,
      from: from,
      to: to,
    );
  }

  @override
  List<Object?> get props => <Object?>[group, list, from, to];
}

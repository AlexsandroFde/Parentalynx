part of 'device_events_bloc.dart';

sealed class DeviceEventsEvent extends Equatable {
  const DeviceEventsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A tela abriu para um aparelho e um periodo. Sem periodo, mostra os ultimos 7 dias.
final class DeviceEventsStarted extends DeviceEventsEvent {
  const DeviceEventsStarted({
    required this.deviceId,
    required this.deviceToday,
    this.from,
    this.to,
  });

  final String deviceId;
  final String deviceToday;
  final String? from;
  final String? to;

  @override
  List<Object?> get props => <Object?>[deviceId, deviceToday, from, to];
}

/// A pessoa escolheu um grupo de eventos (Bloqueios, Limite, Seguranca...).
final class DeviceEventsGroupSelected extends DeviceEventsEvent {
  const DeviceEventsGroupSelected(this.group);

  final EventGroup group;

  @override
  List<Object?> get props => <Object?>[group];
}

/// Carregar a pagina seguinte.
final class DeviceEventsMoreRequested extends DeviceEventsEvent {
  const DeviceEventsMoreRequested();
}

/// Tentar de novo depois de uma falha (da primeira pagina ou da seguinte).
final class DeviceEventsRetried extends DeviceEventsEvent {
  const DeviceEventsRetried();
}
